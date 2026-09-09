--!strict

return table.freeze({
	BaseSpeed = 32,
	StealHoldSeconds = 2,
	InitialNpcGap = 24,
	MaximumNpcGap = 24,
	HitGapPenalty = 8,
	GapRecoveryDelay = 2,
	GapRecoveryPerSecond = 1,
	-- Field guards accelerate through GuardMotion. The minigame pursuer never does.
	NpcSpeedOffset = 0,
	NpcMaximumSpeed = 64,
	CatchGap = 0,
	SlotRefillSeconds = 60,
	JoinWindowSeconds = 10,
	OwnerInitialGap = 28,
	PlayerCatchDistance = 3,
	PlayerCatchHoldSeconds = 0.35,
})

