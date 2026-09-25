Config = {}

Config.Item = 'policetape'

Config.Jobs = {
    police = 0,
}

Config.ConsumeItem       = true
Config.RollLength        = 50.0
Config.MaxTapesPerPlayer = 10
Config.Lifetime          = 60

Config.Texture = {
    dict = 'prop_police_tape',
    name = 'POLICE_TAPE',
    aspect = 994 / 29,
}

Config.Tape = {
    width        = 0.10,
    minLength    = 0.5,
    maxLength    = 25.0,
    maxPoints    = 8,
    sagPerMeter  = 0.008,
    maxSag       = 0.20,
    subdivisions = 4,
    renderDistance = 80.0,
    color        = { 255, 255, 255, 255 },
}

Config.Terrain = {
    blockThroughWalls = true,
    collisionFlags    = 1 | 16,
    groundClearance   = 0.05,
}

Config.Wind = {
    enabled   = true,
    base      = 0.015,
    perSpeed  = 0.006,
    max       = 0.08,
    speed     = 2.2,
}

Config.Blip = {
    enabled = true,
    sprite  = 1,
    color   = 38,
    scale   = 0.6,
    label   = 'Afspærring',
}

Config.Prop = {
    enabled = true,
    model   = 'prop_ducktape_01',
    bone    = 57005,
    pos     = vec3(0.12, 0.02, -0.03),
    rot     = vec3(10.0, 90.0, 0.0),
}

Config.Place = {
    maxDistance  = 5.0,
    groundHeight = 1.0,
    duration     = 2500,
    anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
}

Config.Remove = {
    duration     = 2000,
    interactDist = 2.0,
    displayDist  = 6.0,
}
