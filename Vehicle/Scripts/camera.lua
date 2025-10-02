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
	_camera: Instance, -- typeof(workspace.CurrentCamera) returned Instance
	_current_camera_position: Node,
	_camera_positions: {_head: Node},
	_rearview_camera: Node,
	
	new: ({Attachment}) -> Camera,
	enable: (self: Camera) -> (),
	disable: (self: Camera) -> (),
	change_camera: (self: Camera, rearview_flag: boolean?) -> (),
	update: (self: Camera) -> (),
	destroy: (self: Camera) -> (),
}, Camera))

type Node = typeof(setmetatable({} :: {
	_data: any,
	_next: Node | nil,
}, Node))

local Node = {}
Node.__index = Node

function Node.new(data: any): Node
	return setmetatable({
		_data = data,
		_next = nil,
	}, Node)
end

local function create_circular_singly_linked_list(data: {any}): {}
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
		prev._next = list._head
	end
	
	return list
end

function Camera.new(camera_positions: {Attachment}, rearview_camera): Camera
	local list = create_circular_singly_linked_list(camera_positions)
	return setmetatable({
		enabled = true,
		_camera = workspace.CurrentCamera,
		_camera_positions = list,
		_current_camera_position = list._head,
		_rearview_camera = Node.new(rearview_camera), -- Separate it from the main list as a separate node
	}, Camera)
end

function Camera.enable(self: Camera): ()
	if self.enabled then
		return
	end
	self.enabled = true
	--ContextActionService:BindAction("CHANGE_CURRENT_CAMERA", self:change_camera(), false, Enum.KeyCode.V)

	RunService:BindToRenderStep("UPDATE_CAMERA", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
		
	end)
end

function Camera.disable(self: Camera)
	if not self.enabled then
		return
	end
	self.enabled = false

	--ContextActionService:UnbindAction("CHANGE_CURRENT_CAMERA")
	RunService:UnbindFromRenderStep("UPDATE_CAMERA")
end

function Camera.change_camera(self: Camera, rearview: boolean?): ()
	if rearview then
		self._rearview_camera._next = self._current_camera_position
		self._current_camera_position = self._rearview_camera
		return
	end
	
	self._current_camera_position = self._current_camera_position._next
end

function Camera.update(self: Camera): ()
	self._camera.CFrame = self._current_camera_position._data.WorldCFrame
end

function Camera.destroy(self: Camera): ()
	if self.enabled then
		self:disable()
	end
	
	for k, v in pairs(self) do
		self[k] = nil
	end
end

return Camera
