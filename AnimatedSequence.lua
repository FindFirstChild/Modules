--!nonstrict
-- ALL MY PROGRESS IS GONE WHEN KEYFRAMES() RETURN {INSTANCE}

local AnimatedSequence={}

type self={
	Speed:number,
	Weight:number,
	FadeTime:number,
	Looped:boolean,
	Playing:boolean,
	Play:(self,FadeTime:number?,Weight:number?,Speed:number?)->(),
	Stop:(self)->(),
	AdjustSpeed:(self,Speed:number)->(),
	KeyframeSequence:KeyframeSequence,
	Ended:typeof(Instance.new'BindableEvent'.Event),
	Stored:{[string]:{
		Motor:Joint,
		Part0:CFrame,
		Part1:CFrame
	}},
	Origins:{[string]:CFrame}
}

export type ItselfClass=typeof(setmetatable({}::self,AnimatedSequence))
export type Joint=Motor6D|Weld
--local AnimationID='9747445579'
-- leave AnimID empty to permanently replicate Motor6D to current character
--local Speed=1.5
--local Looped=true

export type TCharacter=Model&{
	Humanoid:Humanoid&{
		Animator:Animator	
	},
	HumanoidRootPart:BasePart&{
		RootJoint:Motor6D	
	},
	Torso:BasePart,
	Animate:LocalScript,
} --unfinished type set

local Players=game:GetService'Players'
local InsertService=game:GetService'InsertService'
local TweenService=game:GetService'TweenService'
local Debris=game:GetService'Debris'
local ReplicatedStorage=game:GetService'ReplicatedStorage'
local RunService=game:GetService'RunService'

local WaitTable={RunService.Stepped,RunService.Heartbeat,RunService.RenderStepped}

local LocalPlayer=Players.LocalPlayer
local Character=LocalPlayer.Character
local Humanoid=Character.Humanoid
local HumanoidRootPart=Character.HumanoidRootPart
local Torso=Character.Torso
local Animate=Character.Animate
local Animator=Humanoid.Animator
--[[
local LocalPlayer=Players.LocalPlayer
local Character:TCharacter=LocalPlayer.Character
local Humanoid=Character.Humanoid
local HumanoidRootPart=Character.HumanoidRootPart
local Torso=Character.Torso
local Animate=Character.Animate
local Animator=Humanoid.Animator
]]

local function SolveC1(P0:CFrame,P1:CFrame,C0:CFrame,CF:CFrame):CFrame
	--[[Formula:
		Motor6D.Transform = Pose.CFrame
	
		Part0.CFrame * Motor6D.C0 * Motor6D.Transform = Part1.CFrame * Motor6D.C1
		A*((B*C)*D) = A*(B*C)*D = (A*(B*C))*D = (A*B*C)*D = A*B*C*D
	]]
	return P1:Inverse()*P0*C0*CF:Inverse()
end

local function GetKeyframes(Sequence:KeyframeSequence)
	local Keyframes=Sequence:GetKeyframes()
	table.sort(Keyframes,function(a,b)
		return a.Time<b.Time
	end)
	return Keyframes
end

local function GetTime():number
	return workspace:GetServerTimeNow()
end

local function GetBasicR6(rig)
	--[[local ModelData = {}
	local motors = {}
	local motorsOriginalOffset = {}
	local a
	local joint
	local function findJoint(bodyPartName,jointName)
		a = rig:FindFirstChild(bodyPartName)
		if a then
			joint = rig:FindFirstChild("Torso"):FindFirstChild(jointName)
			if joint then
				table.insert(motors,motors[a.Name])
				motors[a.Name] = joint
			end
		end
	end
	local function addOffset(name,offset)
		if motors[name] ~= nil then
			table.insert(motorsOriginalOffset,motorsOriginalOffset[name])
			motorsOriginalOffset[name] = offset
		end
	end

	findJoint("Head","Neck")
	findJoint("Left Arm","Left Shoulder")
	findJoint("Left Leg","Left Hip")
	findJoint("Right Arm","Right Shoulder")
	findJoint("Right Leg","Right Hip")
	a = rig:FindFirstChild("Torso")
	if a then
		joint = rig:FindFirstChild("HumanoidRootPart"):FindFirstChild("RootJoint")
		table.insert(motors,motors[a.Name])
		motors[a.Name] = joint
	end
	addOffset("Head",CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	addOffset("Left Arm",CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	addOffset("Left Leg",CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	addOffset("Right Arm",CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	addOffset("Right Leg",CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	addOffset("Torso",CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	--Motors offset
	table.insert(ModelData,ModelData.MotorsData)
	ModelData["MotorsData"] = motors
	table.insert(ModelData,ModelData.Offsets)
	ModelData["Offsets"] = motorsOriginalOffset
	a = nil
	joint = nil
	return ModelData]]
end

function AnimatedSequence.LoadAnimation(self,ID:KeyframeSequence|string):ItselfClass?
	local Ended=Instance.new'BindableEvent'
	AnimatedSequence.__index=function(t,k)
		--print(t,k)
		if k=='Ended'then
			--im too lazy to implement newproxy()
			--print'hi'
			return Ended.Event
		end
		return AnimatedSequence[k]
	end
	local self=setmetatable({}::self,AnimatedSequence)
	local NewSequence
	if typeof(ID)=='Instance' then
		NewSequence=ID
	else
		local Success,Error=pcall(function()
	    	NewSequence=InsertService:LoadLocalAsset(ID)
		end)
		if not Success then 
			error'Failed to load animation'
			--return
		end
	end
	NewSequence.Parent=ReplicatedStorage
	self.Ended=Ended
	self.Stored={}
	self.Origins={}
	self.KeyframeSequence=NewSequence
	self.Speed=1
	self.FadeTime=1
	self.Weight=1
	self.Looped=false
	self.Playing=false
	return self
end
function AnimatedSequence.Play(self:self,FadeTime:number?,Weight:number?,Speed:number?):()
	self.Speed=Speed or self.Speed
	self.FadeTime=FadeTime or 0
	self.Weight=Weight or 0
	local Stored=self.Stored
	local Origins=self.Origins
	local Sequence=self.KeyframeSequence
	local RequiredJoints={}
	for _,PV in Sequence:GetDescendants()do
		if not PV:IsA'Pose'or table.find(RequiredJoints,PV.Name)then continue end
		table.insert(RequiredJoints,PV.Name)
	end
	for _,PV in Torso:GetChildren()do
		if not PV:IsA'Motor6D'then continue end
		local Part0,Part1=PV.Part0,PV.Part1
		if not(Part0 and Part1)then continue end
		Stored[Part1.Name]={
			['Motor']=PV,
			['Part0']=Part0.CFrame,
			['Part1']=Part1.CFrame
		}
		Origins[Part1.Name]=PV.C1
	end
	do
		local RootJoint=HumanoidRootPart.RootJoint
		local Part0,Part1=RootJoint.Part0,RootJoint.Part1
		if Part0 and Part1 then
			Stored[Part1.Name]={
				['Motor']=RootJoint,
				['Part0']=Part0.CFrame,
				['Part1']=Part1.CFrame
			}
            Origins[Part1.Name]=RootJoint.C1
		end
	end
	Animate.Enabled=false
	if Animator then
		for _,PV in Animator:GetPlayingAnimationTracks()do
			PV:Stop() 
		end 
	end
	self.Playing=true
	local Tick=Instance.new'NumberValue'
	Tick.Parent=ReplicatedStorage
	task.spawn(function()
		while Tick do
			Tick.Value+=1
			WaitTable[Tick.Value]:Wait()
			if Tick.Value==3 then
				Tick.Value=0
			end
		end
	end)
	
	--0.005555 second | 180 FPS
	
	local Keyframes=GetKeyframes(Sequence)

	local function PlaySequence():()
		local GlobalTime=GetTime()
		local LastFrameTime:number=0
		for _,Keyframe in Keyframes do
			local Time=(Keyframe.Time-LastFrameTime)/self.Speed
			local CurTime=GetTime()
			LastFrameTime=Keyframe.Time
			GlobalTime+=Time
			if CurTime>GlobalTime then continue end
			local OriginalKC1={}
			for _,Pose in Keyframe:GetDescendants()do
				if Pose.Name==HumanoidRootPart.Name then continue end
				local Info=self.Stored[Pose.Name]
				local Motor=Info.Motor
				OriginalKC1[Pose.Name]=Motor.C1
			end
			-- /Time
			
			while CurTime<=GlobalTime do
				if not self.Playing then 
					return 
				end
				local Dist=GlobalTime-CurTime
				task.spawn(function()
					for _,Pose in Keyframe:GetDescendants()do
			            if Pose.Name==HumanoidRootPart.Name then continue end
						local Info=self.Stored[Pose.Name]
			            local Motor=Info.Motor
						
						local Transform=Pose.CFrame
						local Alpha=TweenService:GetValue(math.max(0,1-Dist/Time),Pose.EasingStyle.Value,Pose.EasingDirection.Value)
						
						Motor.C1=OriginalKC1[Pose.Name]:Lerp(SolveC1(Info.Part0,Info.Part1,Motor.C0,Pose.CFrame),Alpha)
					end
				end)
				--end)
				Tick.Changed:Wait()
				--task.wait()
				CurTime=GetTime()
			end
		end
	end
	task.defer(function()
		while self.Playing do
			PlaySequence()
			if not self.Looped then
				break
			end
		end
		self:Stop()
		Tick:Destroy()
	end)
end

function AnimatedSequence.AdjustSpeed(self:ItselfClass,Speed:number):()
	self.Speed=Speed or self.Speed
end

function AnimatedSequence.Stop(self:self):()
	rawget(self,'Ended'):Fire()
	Debris:AddItem(self.KeyframeSequence)
	for Name,PV in self.Stored do
        PV.Motor.C1=self.Origins[Name]
	end
	self.Looped=false
	self.Playing=false
	Animate.Enabled=true
	--setmetatable(self,nil)
end

return AnimatedSequence