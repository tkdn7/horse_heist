--!strict

return table.freeze({
	BaseSpeed = 32,
	InitialNpcGap = 24,
	MaximumNpcGap = 24,
	HitGapPenalty = 8,
	GapRecoveryDelay = 2,
	GapRecoveryPerSecond = 1,
	-- NPC runner starts a little slower, then closes in without an unlimited speed ramp.
	NpcStartSpeedOffset = -0.6,
	NpcMaxSpeedAdvantage = 0.4,
	NpcAcceleration = 0.06,
	NpcAccelerationDelay = 3,
	NpcMaximumSpeed = 64,
	CatchGap = 0,
	SlotRefillSeconds = 60,
	JoinWindowSeconds = 10,
	OwnerInitialGap = 28,
	OwnerBoostCooldown = 10,
	OwnerBoostDuration = 1,
	OwnerBoostMultiplier = 1.25,
	PlayerCatchDistance = 3,
	PlayerCatchHoldSeconds = 0.35,
})

