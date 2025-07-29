local RunService = game:GetService("RunService")

local Camera = {}
Camera.__index = Camera

export type Camera = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	enabled: boolean,
	_camera: Instance, -- typeof(workspacce.CurrentCamera) returned Instance
	_current_camera_position: Attachment,
	_camera_positions: {Attachment},
	
	new: ({Attachment}) -> Camera,
	change_camera: (self: Camera) -> (),
	update: (self: Camera) -> (),
	enable: (self: Camera) -> (),
	disable: (self: Camera) -> (),
}, Camera))

function Camera.new(vehicle: Vehicle, camera_positions: {Attachment}): Camera
	local self = setmetatable({}, Camera)
	self._vehicle = vehicle
	self.enabled = true
	self._camera = workspace.CurrentCamera
	self._current_camera_position = nil
	self._camera_positions = camera_positions
	
	return self
end

local index = 1
function Camera.change_camera(self: Camera): ()
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
	
	RunService:BindToRenderStep("UPDATE_CAMERA", Enum.RenderPriority.Camera, function()
		self:update()
	end)
end

function Camera.disable(self: Camera)
	if not self.enabled then
		return
	end
	self.enabled = false
	
	RunService:UnbindFromRenderStep("UPDATE_CAMERA")
end

return Camera
