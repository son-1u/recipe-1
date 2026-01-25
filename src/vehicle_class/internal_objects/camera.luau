--[[
Simple camera controller, I might allow for extra features (darkening, shaking, speed-up effect)
]]--

-------------------------------SERVICES-------------------------------

local RunService = game:GetService("RunService")

-----------------------------CAMERA CLASS-----------------------------

local Camera = {}
Camera.__index = Camera

export type Camera = typeof(setmetatable({} :: {
	enabled: boolean,
	_camera: Camera,
	_current_camera_position: Node,
	_camera_positions: {_head: Node},
	_rearview_camera: Node,
	_get_movement_data: () -> {number},
	
	new: (camera_positions: {Attachment}, rearview_camera: Attachment?, get_movement_data: () -> Vector3) -> Camera,
	enable: (self: Camera) -> (),
	disable: (self: Camera) -> (),
	change_camera: (self: Camera, rearview_flag: boolean?) -> (),
	update: (self: Camera, dt: number) -> (),
	destroy: (self: Camera) -> (),
}, Camera))

local Node = {}
Node.__index = Node

type Node = typeof(setmetatable({} :: {
	_data: any,
	_next: Node | nil,
}, Node))

function Node.new(data: any): Node
	return setmetatable({
		_data = data,
		_next = nil,
	}, Node)
end

local function create_circular_singly_linked_list(data: {any}): {_head: Node}
	local list = {_head = nil}
	local prev = nil
	for _, d in ipairs(data) do
		local node = Node.new(d)

		if list._head == nil then
			list._head = node
		else
			prev._next = node
		end
		
		prev = node
	end
	prev._next = list._head
	
	return list
end

function Camera.new(camera_positions: {Attachment}?, rearview_camera: Attachment?, get_movement_data: () -> Vector3, camera_settings: {[Enum]: any}): Camera
	local list
	if camera_positions ~= nil then
		list = create_circular_singly_linked_list(camera_positions)
	end
	return setmetatable({
		enabled = false,
		_camera = workspace.CurrentCamera,
		_camera_positions = list,
		_current_camera_position = list._head, -- Possibly implement support for no camera modes?
		_rearview_camera = rearview_camera and Node.new(rearview_camera) or nil, -- Separate it from the main list as a separate node
		_get_movement_data = get_movement_data or function()
			return Vector3.zero
		end,
		_camera_x_shake_multiplier = camera_settings,
		_camera_y_shake_multiplier = camera_settings,
		_camera_z_shake_multiplier = camera_settings,
	}, Camera)
end

function Camera.enable(self: Camera): ()
	if self.enabled then
		return
	end
	self.enabled = true

	RunService:BindToRenderStep("UPDATE_CAMERA", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
		self:update(dt)
	end)
end

function Camera.disable(self: Camera)
	if not self.enabled then
		return
	end
	self.enabled = false

	RunService:UnbindFromRenderStep("UPDATE_CAMERA")
end

function Camera.change_camera(self: Camera, rearview: boolean?): ()
	if rearview and self._rearview_camera then
		self._rearview_camera._next = self._current_camera_position
		self._current_camera_position = self._rearview_camera
		return
	end
	
	self._current_camera_position = self._current_camera_position._next
end

function Camera.update(self: Camera, dt: number): ()
	local position: CFrame = self._current_camera_position._data.WorldCFrame
	local movement_data: Vector3 = self._get_movement_data()
	
	--position.Position += Vector3.new(movement_data.X *)
	
	self._camera.CFrame = position
end

function Camera.destroy(self: Camera): ()
	if self.enabled then
		self:disable()
	end
	
	for k, v in pairs(self) do
		self[k] = nil
	end
end

setmetatable(Camera, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

return Camera
