class FlappyWingsMutator extends GGMutator;

var array<FlappyWingsComponent> mComponents;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local FlappyWingsComponent flappyComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		flappyComp=FlappyWingsComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'FlappyWingsComponent', goat.mCachedSlotNr));
		if(flappyComp != none && mComponents.Find(flappyComp) == INDEX_NONE)
		{
			mComponents.AddItem(flappyComp);
		}
	}
}

event Tick( float deltaTime )
{
	local FlappyWingsComponent fwc;

	super.Tick( deltaTime );

	foreach mComponents(fwc)
	{
		fwc.Tick( deltaTime );
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'FlappyWingsComponent'
}