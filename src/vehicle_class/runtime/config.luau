local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Curve = require(ReplicatedStorage.module_scripts.vehicle.client_vehicle.internal_objects.curve)
local Enums = require(ReplicatedStorage.module_scripts.vehicle.client_vehicle.utils.enums)

return {
	engine = {
		engine_inertia = 0.1,
		idle_throttle = 0.05,
		min_rpm = 5500,
		max_rpm = 13600,
		torque_curve = {
			points = {
				Vector2.new(0, 0),
				Vector2.new(7240, 625),
				Vector2.new(13600, 200),
			},
			type = Curve.CurveType.QUADRATIC_BEZIER,
		},
	},
	electric_motor = {
		motor_inertia = 0.05,
		idle_throttle = 0.05,
		min_rpm = 0,
		max_rpm = 50000,
		torque_curve = {
			points = {
				Vector2.new(0, 381.25),
				Vector2.new(16370, 75),
				Vector2.new(50000, 75),
			},
			type = Curve.CurveType.QUADRATIC_BEZIER,
		},
	},
	turbocharger = {
		turbine_inertia = 0.05,
		max_rpm = 125000,
		boost_curve = {
			points = {
				Vector2.new(0, 0),
				Vector2.new(38000, 0),
				Vector2.new(29200, 3.76),
				Vector2.new(2000, 3.8),
				Vector2.new(125000, 3.8),
			},
			type = Curve.CurveType.QUARTIC_BEZIER,
		},
	},
	gearbox = {
		gear_ratios = {
			2.95, 2.47, 1.975, 1.66, 1.4125, 1.2525, 1.125, 1
		},
		final_drive_ratio = 4.2,
		shift_time = 0,
	},
	steering_column = {
		max_steering_angle = 35,
		steering_speed = 1.5,
	},
	wheel = {
		wheel_radius = 1.5,
		wheel_inertia = 0.8,
		suspension_length = 1.5,
		suspension_stiffness = 4,
		suspension_damping = 1,
		
		long_slip_curve = {
			points = {
				Vector2.new(0, 0),
				Vector2.new(0.126, 0.58),
				Vector2.new(0.6, 1.2),
				Vector2.new(0.276, 1.156),
				Vector2.new(math.pi/2, 0.645)
			},
			type = Curve.CurveType.QUARTIC_BEZIER
		},
		lat_slip_curve = {
			points = {
				Vector2.new(0, 0),
				Vector2.new(0.126, 0.58),
				Vector2.new(0.6, 1.2),
				Vector2.new(0.276, 1.156),
				Vector2.new(math.pi/2, 0.645)
			},
			type = Curve.CurveType.QUARTIC_BEZIER
		}
	},
	
	keybinds = {
		kb_throttle = Enum.KeyCode.W,
		kb_throttle_alt = Enum.KeyCode.Up,
		kb_brake = Enum.KeyCode.S,
		kb_brake_alt = Enum.KeyCode.Down,
		kb_steer_left = Enum.KeyCode.A,
		kb_steer_left_alt = Enum.KeyCode.Left,
		kb_steer_right = Enum.KeyCode.D,
		kb_steer_right_alt = Enum.KeyCode.Right,
		kb_shift_up = Enum.KeyCode.E,
		kb_shift_down = Enum.KeyCode.Q,
		
		gamepad_throttle = Enum.KeyCode.ButtonR2,
		gamepad_brake = Enum.KeyCode.ButtonL2,
		gamepad_steer = Enum.KeyCode.Thumbstick1,
		gamepad_shift_up = Enum.KeyCode.ButtonA,
		gamepad_shift_down = Enum.KeyCode.ButtonX
	},
	
	drivetrain = Enums.Drivetrain.RWD,
	
	downforce_enabled = true,
	downforce_percentage = 50,
	downforce_curve = {
		points = {
			Vector2.new(0, 0),
			Vector2.new(250, 0),
			Vector2.new(500, -523688)
		},
		type = Curve.CurveType.QUADRATIC_BEZIER
	},
	
	slipstream_enabled = true,
	slipstream_curve = {
		points = {
			Vector2.new(0, 3900),
			Vector2.new(188, 4150),
			Vector2.new(47, -380),
			Vector2.new(300, 0)
		},
		type = Curve.CurveType.CUBIC_BEZIER
	}
}
