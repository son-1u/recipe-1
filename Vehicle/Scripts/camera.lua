--[[
Simple camera controller, I might allow for extra features (darkening, shaking, speed-up effect)
]]--

-------------------------------SERVICES-------------------------------

local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

-----------------------------CAMERA CLASS-----------------------------

local Camera = {}
Camera.__index = Camera

export type Camera = typeof(setmetatable({} :: {
	enabled: boolean,
	_camera: Instance, -- typeof(workspacce.CurrentCamera) returned Instance
	_current_camera_position: Attachment,
	_camera_positions: {Attachment},
	
	new: ({Attachment}) -> Camera,
	change_camera: (self: Camera) -> (),
	update: (self: Camera) -> (),
	enable: (self: Camera) -> (),
	disable: (self: Camera) -> (),
	destroy: (self: Camera) -> (),
}, Camera))

function Camera.new(camera_positions: {Attachment}): Camera
	return setmetatable({
		enabled = true,
		_camera = workspace.CurrentCamera,
		_current_camera_position = nil,
		_camera_positions = camera_positions
	}, Camera)
end

local index = 1
function Camera.change_camera(self: Camera): () -- Would use a linked list, but oh well
	index += 1
	if index > #self._camera_positions then
		index = 1
	end
	self._current_camera_position = self._camera_positions[index]
end

function Camera.update(self: Camera): ()
	self._camera.CFrame = self._current_camera_position.WorldCFrame
end

function Camera.enable(self: Camera): ()
	if self.enabled then
		return
	end
	self.enabled = true
	
	ContextActionService:BindAction("CHANGE_CURRENT_CAMERA", self:change_camera(), false, Enum.KeyCode.V)
	
	RunService:BindToRenderStep("UPDATE_CAMERA", Enum.RenderPriority.Camera, function()
		self:update()
	end)
end

function Camera.disable(self: Camera)
	if not self.enabled then
		return
	end
	self.enabled = false
	
	ContextActionService:UnbindAction("CHANGE_CURRENT_CAMERA")
	RunService:UnbindFromRenderStep("UPDATE_CAMERA")
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
