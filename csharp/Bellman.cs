using Godot;
using System.Collections.Generic;

// The Bellman: stalks the orphanage on a grid, rings his hand bell as he walks
// (faster when he is hunting), turns towards noises and chases on sight.
// Members are snake_case on purpose so GDScript can call them by those names.
public partial class Bellman : CharacterBody3D
{
	public string state = "dormant"; // dormant, wander, investigate, chase, search
	public float walk_speed = 1.35f;
	public float chase_speed = 3.15f;
	public float catch_range = 1.05f;
	public float sight_range = 13.0f;

	char[][] grid;
	float cell = 2.0f;
	Node3D player;
	Node main;
	readonly List<Vector3> path = new();
	Vector3 goal;
	Vector3 last_seen;
	float repath_t, bell_t, lost_t, search_t, idle_t;
	readonly RandomNumberGenerator rng = new();
	public AudioStreamPlayer3D bell;
	Node3D body;

	public void setup(string[] rows, float cell_size, Node3D player_node, Node main_node, AudioStream bell_stream)
	{
		grid = new char[rows.Length][];
		for (int i = 0; i < rows.Length; i++)
			grid[i] = rows[i].ToCharArray();
		cell = cell_size;
		player = player_node;
		main = main_node;
		rng.Randomize();
		CollisionLayer = 4;
		CollisionMask = 1;
		var cs = new CollisionShape3D();
		cs.Shape = new CapsuleShape3D { Radius = 0.35f, Height = 2.1f };
		cs.Position = new Vector3(0, 1.05f, 0);
		AddChild(cs);
		build_body();
		bell = new AudioStreamPlayer3D
		{
			Stream = bell_stream,
			UnitSize = 4.0f,
			MaxDistance = 40.0f,
			AttenuationModel = AudioStreamPlayer3D.AttenuationModelEnum.InverseDistance,
			Position = new Vector3(0.45f, 1.1f, 0),
			Bus = "SFX",
		};
		AddChild(bell);
	}

	// Greybox body: a tall coat, a pale mask and the hand bell. Real model later.
	void build_body()
	{
		body = new Node3D();
		AddChild(body);
		var coat = new StandardMaterial3D { AlbedoColor = new Color(0.07f, 0.06f, 0.06f) };
		var mask = new StandardMaterial3D { AlbedoColor = new Color(0.85f, 0.82f, 0.74f), EmissionEnabled = true, Emission = new Color(0.12f, 0.11f, 0.1f) };
		var brass = new StandardMaterial3D { AlbedoColor = new Color(0.55f, 0.42f, 0.18f), Metallic = 0.6f };
		var c = new MeshInstance3D { Mesh = new CylinderMesh { TopRadius = 0.22f, BottomRadius = 0.42f, Height = 1.75f, RadialSegments = 8 }, MaterialOverride = coat, Position = new Vector3(0, 0.875f, 0) };
		body.AddChild(c);
		var h = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.3f, 0.38f, 0.26f) }, MaterialOverride = mask, Position = new Vector3(0, 1.98f, -0.02f) };
		body.AddChild(h);
		var hat = new MeshInstance3D { Mesh = new CylinderMesh { TopRadius = 0.2f, BottomRadius = 0.2f, Height = 0.32f, RadialSegments = 8 }, MaterialOverride = coat, Position = new Vector3(0, 2.3f, 0) };
		body.AddChild(hat);
		var brim = new MeshInstance3D { Mesh = new CylinderMesh { TopRadius = 0.36f, BottomRadius = 0.36f, Height = 0.03f, RadialSegments = 8 }, MaterialOverride = coat, Position = new Vector3(0, 2.15f, 0) };
		body.AddChild(brim);
		var b = new MeshInstance3D { Mesh = new CylinderMesh { TopRadius = 0.04f, BottomRadius = 0.12f, Height = 0.18f, RadialSegments = 8 }, MaterialOverride = brass, Position = new Vector3(0.45f, 1.05f, -0.1f) };
		body.AddChild(b);
	}

	public void wake()
	{
		if (state == "dormant")
		{
			state = "wander";
			pick_wander();
		}
	}

	public void rest()
	{
		state = "dormant";
		path.Clear();
		Velocity = Vector3.Zero;
	}

	public void set_cell(int x, int y, string ch)
	{
		if (y >= 0 && y < grid.Length && x >= 0 && x < grid[y].Length && ch.Length > 0)
			grid[y][x] = ch[0];
	}

	public void hear(Vector3 pos, float radius)
	{
		if (state == "dormant" || state == "chase")
			return;
		if (GlobalPosition.DistanceTo(pos) > radius)
			return;
		state = "investigate";
		go_to(pos);
	}

	// ------------------------------------------------------------- grid
	bool walkable(int x, int y)
	{
		if (y < 0 || y >= grid.Length || x < 0 || x >= grid[y].Length)
			return false;
		char ch = grid[y][x];
		return ch != '#' && ch != 'L' && ch != ' ';
	}

	public Vector2I cell_of(Vector3 p) => new((int)Mathf.Floor(p.X / cell), (int)Mathf.Floor(p.Z / cell));

	public Vector3 center(Vector2I c) => new(c.X * cell + cell / 2, 0, c.Y * cell + cell / 2);

	static readonly Vector2I[] Dirs = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

	public int path_length_to(Vector3 to)
	{
		var p = bfs(cell_of(GlobalPosition), cell_of(to));
		return p == null ? -1 : p.Count;
	}

	List<Vector2I> bfs(Vector2I from, Vector2I to)
	{
		if (!walkable(to.X, to.Y))
			return null;
		var prev = new Dictionary<Vector2I, Vector2I>();
		var q = new Queue<Vector2I>();
		q.Enqueue(from);
		prev[from] = from;
		while (q.Count > 0)
		{
			var c = q.Dequeue();
			if (c == to)
				break;
			foreach (var d in Dirs)
			{
				var n = c + d;
				if (!walkable(n.X, n.Y) || prev.ContainsKey(n))
					continue;
				prev[n] = c;
				q.Enqueue(n);
			}
		}
		if (!prev.ContainsKey(to))
			return null;
		var res = new List<Vector2I>();
		var cur = to;
		while (cur != from)
		{
			res.Add(cur);
			cur = prev[cur];
		}
		res.Reverse();
		return res;
	}

	void go_to(Vector3 p)
	{
		goal = p;
		path.Clear();
		var cells = bfs(cell_of(GlobalPosition), cell_of(p));
		if (cells == null)
			return;
		foreach (var c in cells)
			path.Add(center(c));
		if (path.Count > 0)
			path[path.Count - 1] = new Vector3(p.X, 0, p.Z);
	}

	// Wandering stays loosely near the player so the bell never goes quiet for long.
	void pick_wander()
	{
		var pc = cell_of(player.GlobalPosition);
		for (int tries = 0; tries < 40; tries++)
		{
			int x, y;
			if (rng.Randf() < 0.55f)
			{
				x = pc.X + rng.RandiRange(-6, 6);
				y = pc.Y + rng.RandiRange(-5, 5);
			}
			else
			{
				y = rng.RandiRange(0, grid.Length - 1);
				x = rng.RandiRange(0, grid[y].Length - 1);
			}
			if (walkable(x, y) && new Vector2I(x, y) != cell_of(GlobalPosition))
			{
				go_to(center(new Vector2I(x, y)));
				if (path.Count > 0)
					return;
			}
		}
	}

	// ------------------------------------------------------------- senses
	public bool can_see_player()
	{
		if (player == null || (bool)player.Get("hidden"))
			return false;
		var eye = GlobalPosition + new Vector3(0, 1.9f, 0);
		var target = player.GlobalPosition + new Vector3(0, 1.4f, 0);
		float d = eye.DistanceTo(target);
		bool lit = (bool)player.Get("light_on");
		float range = lit ? sight_range * 1.4f : sight_range;
		if (d > range)
			return false;
		var fwd = -GlobalTransform.Basis.Z;
		var to = (target - eye).Normalized();
		if (d > 2.5f && fwd.Dot(to) < 0.35f)
			return false;
		var q = PhysicsRayQueryParameters3D.Create(eye, target, 1);
		var hit = GetWorld3D().DirectSpaceState.IntersectRay(q);
		return hit.Count == 0;
	}

	public override void _PhysicsProcess(double delta)
	{
		float dt = (float)delta;
		if (state == "dormant" || player == null)
			return;
		if ((string)main.Get("mode") != "play")
		{
			Velocity = Vector3.Zero;
			return;
		}
		bool sees = can_see_player();
		if (sees)
		{
			last_seen = player.GlobalPosition;
			lost_t = 0;
			if (state != "chase")
			{
				state = "chase";
				main.Call("on_chase_start");
			}
		}

		switch (state)
		{
			case "chase":
				repath_t -= dt;
				if (repath_t <= 0)
				{
					repath_t = 0.35f;
					go_to(sees ? player.GlobalPosition : last_seen);
				}
				if (!sees)
				{
					lost_t += dt;
					if (lost_t > 3.0f)
					{
						state = "search";
						search_t = 7.0f;
						go_to(last_seen);
						main.Call("on_chase_end");
					}
				}
				break;
			case "search":
				search_t -= dt;
				if (path.Count == 0 && search_t > 0)
				{
					var c = cell_of(last_seen) + new Vector2I(rng.RandiRange(-2, 2), rng.RandiRange(-2, 2));
					if (walkable(c.X, c.Y))
						go_to(center(c));
				}
				if (search_t <= 0)
				{
					state = "wander";
					pick_wander();
				}
				break;
			default:
				if (path.Count == 0)
				{
					idle_t += dt;
					if (idle_t > 1.2f)
					{
						idle_t = 0;
						state = "wander";
						pick_wander();
					}
				}
				break;
		}

		float speed = state == "chase" ? chase_speed : walk_speed;
		var v = Vector3.Zero;
		if (path.Count > 0)
		{
			var next = path[0];
			var flat = new Vector3(next.X - GlobalPosition.X, 0, next.Z - GlobalPosition.Z);
			if (flat.Length() < 0.25f)
				path.RemoveAt(0);
			else
				v = flat.Normalized() * speed;
		}
		Velocity = new Vector3(v.X, 0, v.Z);
		MoveAndSlide();
		if (v.LengthSquared() > 0.01f)
		{
			var look = GlobalPosition - v;
			float target_yaw = Mathf.Atan2(-v.X, -v.Z);
			Rotation = new Vector3(0, Mathf.LerpAngle(Rotation.Y, target_yaw, Mathf.Min(1, dt * 8)), 0);
		}
		if (body != null)
			body.Position = new Vector3(0, Mathf.Abs(Mathf.Sin(Time.GetTicksMsec() * 0.006f)) * (v.LengthSquared() > 0.01f ? 0.04f : 0), 0);

		// The hand bell: slow, patient rings while he walks; frantic in a chase.
		bell_t -= dt;
		if (bell_t <= 0)
		{
			bell_t = state == "chase" ? rng.RandfRange(0.4f, 0.6f) : rng.RandfRange(1.4f, 2.2f);
			bell.PitchScale = rng.RandfRange(0.92f, 1.06f);
			bell.VolumeDb = state == "chase" ? 2.0f : -2.0f;
			bell.Play();
		}

		float pd = GlobalPosition.DistanceTo(new Vector3(player.GlobalPosition.X, GlobalPosition.Y, player.GlobalPosition.Z));
		if (pd < catch_range && !(bool)player.Get("hidden"))
			main.Call("caught");
	}
}
