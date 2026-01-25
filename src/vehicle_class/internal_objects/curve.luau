---------------------------------CURVE--------------------------------

local Curve = {}
Curve.__index = Curve

export type Curve = typeof(setmetatable({} :: {
	_curve: {number},

	new: () -> Curve,
	sample: (x: number) -> number,
	destroy: () -> (),
}, Curve))

Curve.CurveType = { -- Public enum
	QUADRATIC_BEZIER = 0,
	CUBIC_BEZIER = 1,
	QUARTIC_BEZIER = 2,
}

local SAMPLE_SIZE = 256

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Calculate p1 based off of p0, p2, and t if this is ever needed
local function calculate_quadratic_bezier_p1(p0: Vector2, curve_peak: Vector2, p2: Vector2): Vector2
	local curve_peak_t = curve_peak.x / p2.x
	local denominator = 2*curve_peak_t*(1 - curve_peak_t)

	return Vector2.new(
		(curve_peak.x - (1 - curve_peak_t)^2 * p0.x - curve_peak_t^2 * p2.x) / denominator,
		(curve_peak.y - (1 - curve_peak_t)^2 * p0.y - curve_peak_t^2 * p2.y) / denominator
	)
end

-- p0: start point
-- p1: control point, defines the curve
-- p2: end point
local function calculate_quadratic_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2): {number}
	p0 = p0 ~= nil and p0 or Vector2.zero
	p1 = p1 ~= nil and p1 or Vector2.zero
	p2 = p2 ~= nil and p2 or Vector2.zero
	
	local curve = table.create(SAMPLE_SIZE)

	for i = 1, SAMPLE_SIZE do
		local t = (i - 1) / (SAMPLE_SIZE - 1)
		local y = (1 - t)^2 * p0.y + 2*(1 - t)*t * p1.y + t^2 * p2.y

		curve[i] = y
	end

	return curve
end

-- p0: start point
-- p1: control point, defines the curve
-- p2: control point, defines the curve
-- p3: end point
local function calculate_cubic_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2): {number}
	p0 = p0 ~= nil and p0 or Vector2.zero
	p1 = p1 ~= nil and p1 or Vector2.zero
	p2 = p2 ~= nil and p2 or Vector2.zero
	p3 = p3 ~= nil and p3 or Vector2.zero
	
	local curve = table.create(SAMPLE_SIZE)

	for i = 1, SAMPLE_SIZE do
		local t = (i - 1) / (SAMPLE_SIZE - 1)
		local y = (1 - t)^3 * p0.y + 3*(1 - t)^2 * t * p1.y + 3*(1 - t)*t^2 * p2.y + t^3 * p3.y

		curve[i] = y
	end

	return curve
end

-- p0: start point
-- p1: control point, defines the curve
-- p2: control point, defines the curve
-- p3: control point, defines the curve
-- p4: end point
local function calculate_quartic_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2): {number}
	p0 = p0 ~= nil and p0 or Vector2.zero
	p1 = p1 ~= nil and p1 or Vector2.zero
	p2 = p2 ~= nil and p2 or Vector2.zero
	p3 = p3 ~= nil and p3 or Vector2.zero
	p4 = p4 ~= nil and p4 or Vector2.zero
	
	local curve = table.create(SAMPLE_SIZE)

	for i = 1, SAMPLE_SIZE do
		local t = (i - 1) / (SAMPLE_SIZE - 1)
		local y = (1 - t)^4 * p0.y + 4*t*(1 - t)^3 * p1.y + 6*(t^2)*(1 - t)^2 * p2.y + 4*(t^3)*(1 - t) * p3.y + t^4 * p4.y

		curve[i] = y
	end

	return curve
end

local CURVE_TYPE_MAP = {
	[Curve.CurveType.QUADRATIC_BEZIER] = {
		fn = calculate_quadratic_bezier_curve,
		points = 3,
	},
	[Curve.CurveType.CUBIC_BEZIER] = {
		fn = calculate_cubic_bezier_curve,
		points = 4,
	},
	[Curve.CurveType.QUARTIC_BEZIER] = {
		fn = calculate_quartic_bezier_curve,
		points = 5,
	},
}
function Curve.new(points: {Vector2}, curve_type: number): Curve
	local curve = CURVE_TYPE_MAP[curve_type]
	if curve == nil then
		error("Could not create curve; invalid curve type")
	end

	if #points < curve.points or #points > curve.points then
		warn("Curve may be inaccurate; incorrect amount of points")
	end

	return setmetatable({
		_curve = curve.fn(table.unpack(points, 1, curve.points))
	}, Curve)
end

-- @t: value between [0, 1] representing a time in the curve. Calculate using point/max_point
function Curve.sample(self: Curve, t: number): number
	t = math.clamp(t, 0, 1)

	-- Get the middle of two indices
	local i = t * (SAMPLE_SIZE - 1)
	local i0 = math.floor(i) + 1
	local i1 = math.min(i0 + 1, SAMPLE_SIZE)

	-- alpha of the lerp function is the decimal value between i0 and i1
	return lerp(self._curve[i0], self._curve[i1], i - math.floor(i))
end

function Curve.destroy(self: Curve): ()
	for k, v in pairs(self) do
		self[k] = nil
	end
end

return Curve
