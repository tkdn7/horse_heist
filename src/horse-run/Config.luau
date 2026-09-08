-- Horse Run prototype. Distances use 1 studio stud = 1 displayed game metre.
return table.freeze({
    Speed = 16, MaxHealth = 60, Drain = 1, Damage = 15,
    CarrotHeal = 1, CarrotValue = 1, LaneWidth = 8,
    LaneDuration = 0.18, JumpDuration = 1.05, JumpHeight = 7,
    JumpCooldown = 1.12, SlideEnter = 0.12, SlideHold = 0.65,
    SlideRecover = 0.18, SlideDuration = 0.95, SlideCooldown = 1.25,
    Countdown = 3, SnapshotInterval = 0.1,
    ChunkLength = 100, ViewDistance = 400, RowLength = 36,
    CourseStart = 80, InitialMoney = 100, Version = 2,
    MaxLevel = 50, MaxUpgradeLevel = 100,
    LevelExpBase = 100, LevelExpGrowth = 1.2,
    UpgradeGrowth = 1.16,
    UpgradeCosts = table.freeze({Speed = 100, Stamina = 100}),
    UpgradeGains = table.freeze({Speed = 0.4, Stamina = 3}),
    AutosaveSeconds = 60,
    RespawnSeconds = 2,
})


