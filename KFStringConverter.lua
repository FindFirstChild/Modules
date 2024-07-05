--!nocheck

local module = {}

local BPwhitelist={'HumanoidRootPart','Torso','Right Arm','Right Leg','Left Arm','Left Leg','Head'}
local LastInfo={}

function module:ToGame(str)
	local data=loadfile(str)()
	local properties=data.Properties
	local keyframes=data.Keyframes
	if not(properties and keyframes)then
		warn'failed to load KF'
		return
	end
	local KeyframeSequence=Instance.new'KeyframeSequence'
	local function DeepSearch(Parent,Table)
		for Idx,Inf in Table do
			if typeof(Inf)=='table'then
				if not table.find(BPwhitelist,Idx)then continue end
				local Pose=Instance.new'Pose'
				Pose.Name=Idx
				local CF=LastInfo[Idx]
				if CF then
					Pose.CFrame=CF
				end
				Pose.Parent=Parent
				DeepSearch(Pose,Inf)
			else
				LastInfo[Parent.Name]=Inf
				Parent.CFrame=Inf
			end
		end
	end
	for Time,Table in keyframes do
		local Keyframe=Instance.new'Keyframe'
		Keyframe.Time=Time
		Keyframe.Parent=KeyframeSequence
		for Idx,Inf in Table do
			DeepSearch(Keyframe,Table)
		end
	end
	KeyframeSequence.Parent=game.ReplicatedStorage
	return KeyframeSequence
end


return module
