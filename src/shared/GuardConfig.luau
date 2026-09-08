return table.freeze({
    SightRange=65,FieldOfView=110,ChaseSpeed=32,PatrolSpeed=8,CatchDistance=3,
    -- Existing Shift sprint is 35; cap only slightly above it, never unbounded.
    FarmerStartSpeed=18,FarmerMaxSpeed=38,FarmerAcceleration=1.5,
    ShowDetectionRange=true,VisualDelay=.12,VisualDistance=220,
    LostSightSeconds=2,Tick=.1,PathInterval=.9,
    AngrySound='rbxassetid://103806783098387',BarkSound='rbxassetid://135016436724006',
    VoiceVolume=.35,VoiceInterval=5,
})
