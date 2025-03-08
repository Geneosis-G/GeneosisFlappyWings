class FlappyWingsComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;


var AnimNodeSlot oldAnimNodeSlot;

var bool isEasterEgg;
var GGFlappyGoatComponent myFGC;
var bool alreadyFlying;

var InterpCurveFloat mNewAirLiftCoefficient;
var InterpCurveFloat mNewAirDragCoefficient;

var SoundCue mWingFlutterCue;
var SoundCue mWindCue;
var SoundCue mFlapCue;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		alreadyFlying=gMe.mCanFly;

		if(gMe.Mesh.SkeletalMesh == SkeletalMesh'FeatherGoat.mesh.FeatherGoat_01'
		|| gMe.Mesh.SkeletalMesh == SkeletalMesh'ClassyGoat.mesh.ClassyGoat_01')
		{
			MakeMeFly();
		}
		gMe.SetTimer(1.f, false, NameOf(FindFlappyGoatComponent), self);
		gMe.SetTimer(1.f, false, NameOf(DestroyWhaleComponent), self);
	}
}

function MakeMeFly()
{
	gMe.mCanFly = true;
	gMe.mAirAccelRate = gMe.mSprintSpeed / 2.f;
	gMe.AirSpeed = gMe.mSprintSpeed * 15.f / 8.f;
	gMe.mAirFlapCooldown = 0.5f;

	gMe.mAirLiftCoefficient = mNewAirLiftCoefficient;
	gMe.mAirDragCoefficient = mNewAirDragCoefficient;
	gMe.mAirSpeedLiftCoefficient = 2.0f;

	gMe.mWingFlutterCue = mWingFlutterCue;
	gMe.mWindCue = mWindCue;

	gMe.mFlapZ = gMe.JumpZ * 7.f / 9.f;
}

function FindFlappyGoatComponent()
{
	myFGC=GGFlappyGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'GGFlappyGoatComponent', gMe.mCachedSlotNr));
	if(myFGC != none)
	{
		if(!gMe.mCanFly) MakeMeFly();
		myFGC.mWings.SetLightEnvironment(gMe.mesh.LightEnvironment);
		myFGC.mWings.SetScale((gMe.CylinderComponent.CollisionRadius + gMe.CylinderComponent.CollisionHeight) / 55.f);
		myFGC.mWings.SetTranslation(vect(0, 0, 1) * (1-myFGC.mWings.scale) * 160.f/9.f);
	}
}

function DestroyWhaleComponent()
{
	local GGMutatorComponentSpermGoat whale;

	whale=GGMutatorComponentSpermGoat(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'GGMutatorComponentSpermGoat', gMe.mCachedSlotNr));
	if(whale != none)
	{
		if(!gMe.mCanFly) MakeMeFly();
		whale.DetachFromPlayer();
		isEasterEgg=true;
		gMe.mLayStill = false;
		gMe.SetRagdoll(false);
	}
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	super.OnPlayerRespawn(respawnController, died);

	if(respawnController.Pawn == gMe && isEasterEgg)
	{
		DestroyWhaleComponent();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			SpeedFlapping(true);
			if(!alreadyFlying && CanFlap())
			{
				gMe.PlaySound(mFlapCue);
			}
		}
		/*if(newKey == 'P')
		{
			myFGC.mWings.SetTranslation(myFGC.mWings.Translation + vect(0, 0, 1));
		}
		if(newKey == 'M')
		{
			myFGC.mWings.SetTranslation(myFGC.mWings.Translation - vect(0, 0, 1));
		}
		myMut.WorldInfo.Game.Broadcast(myMut, myFGC.mWings.Translation);*/
	}
}

function SpeedFlapping(optional bool faster)
{
	local float flapInterval;

	if(myFGC == none)
		return;

	if(gMe.IsTimerActive(NameOf(SpeedFlapping),self))
	{
		gMe.ClearTimer(NameOf(SpeedFlapping),self);
	}

	if(CanFlap())
	{
		flapInterval=faster?0.5f:1.f;
		myFGC.mWings.GlobalAnimRateScale = faster?0.6f:0.3f;
		gMe.SetTimer(flapInterval,false,NameOf(SpeedFlapping),self );
	}
	else
	{
		myFGC.mWings.GlobalAnimRateScale = myFGC.mFlapSpeedIdle;
	}
}

function bool CanFlap()
{
	return gMe.MultiJumpRemaining == 0 && (gMe.Physics == PHYS_Flying || gMe.Physics == PHYS_Falling);
}

function Tick( float deltaTime )
{
	if(alreadyFlying)
		return;

	 UpdateAnim();
	 UpdateRotation(deltaTime);
}

function UpdateAnim()
{
	if(gMe.Physics == PHYS_Flying)
	{
		if(oldAnimNodeSlot == none)
		{
			oldAnimNodeSlot=gMe.mAnimNodeSlot;
			gMe.mAnimNodeSlot=none;
		}
		if( oldAnimNodeSlot.GetPlayedAnimation() != 'Falling' )
		{
			oldAnimNodeSlot.PlayCustomAnim( 'Falling', 1.0f, 0.2f, 0.2f, true, true);
		}
	}
	else
	{
		if(oldAnimNodeSlot != none)
		{
			gMe.mAnimNodeSlot=oldAnimNodeSlot;
			gMe.mAnimNodeSlot.StopCustomAnim( 0.1f );
			oldAnimNodeSlot=none;
		}
	}
}

/*
 * Make the body roll right or left when flying
 */
function UpdateRotation(float deltaTime)
{
	local vector camLocation, lateral, forwardMe;
	local rotator camRotation, flatCamRot, flatRot, desiredRotation;
	local float orientation, angle, maxAngle, newRoll, maxRoll;

	desiredRotation=gMe.mesh.default.Rotation;
	if(gMe.Physics == PHYS_Flying && gMe.Controller != none && gMe.AirControl > 0.f)
	{
		GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
		flatCamRot.Yaw=camRotation.Yaw;
		flatRot.Yaw=gMe.Rotation.Yaw;
		maxAngle=1.5708;
		maxRoll=8192;
		angle=Acos(Normal(vector(flatCamRot)) dot Normal(vector(flatRot)));
		newRoll=angle<maxAngle?maxRoll*angle/maxAngle:maxRoll;

		lateral=Normal(vector(flatCamRot));
		lateral=lateral cross vect(0,0,1);

		forwardMe=gMe.Location + Normal(vector(flatRot))*100.f;
		orientation = lateral dot Normal(forwardMe - camLocation);
		if(orientation > 0.f)
		{
			desiredRotation.Roll+=newRoll;
		}
		else if(orientation < 0.f)
		{
			desiredRotation.Roll+=-newRoll;
		}
	}
	gMe.mesh.SetRotation( RInterpTo( gMe.mesh.Rotation, desiredRotation, deltaTime, 5.0f ) );
}

defaultproperties
{
	mNewAirLiftCoefficient=(Points=((InVal=-20,OutVal=-1.5),(InVal=-10,OutVal=-1.3),(InVal=0,OutVal=0),(InVal=10,OutVal=1.3),(InVal=15,OutVal=1.5),(InVal=20,OutVal=0.5)));
	mNewAirDragCoefficient=(Points=((InVal=-1.6,OutVal=0.280),(InVal=-0.8,OutVal=0.120),(InVal=0,OutVal=0.060),(InVal=0.8,OutVal=0.120),(InVal=1.6,OutVal=0.280)));

	mWingFlutterCue=SoundCue'Heist_Audio.Cue.SFX_Flamingo_Wing_Flutter_Cue'
	mWindCue=SoundCue'Heist_Audio.Cue.SFX_Flamingo_Wind_Cue'
	mFlapCue=SoundCue'Heist_Audio.Cue.SFX_Flamingo_Wing_Flap_Cue'
}