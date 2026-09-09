--!strict

export type RarityId = "Bronze" | "Silver" | "Gold" | "Champion" | "Royal" | "Legend"

export type RarityDefinition = {
	Id: RarityId,
	DisplayName: string,
	SpawnWeight: number,
	StealHoldSeconds: number,
	EscapeSeconds: number,
	MinimumObstacleGapSeconds: number,
	Color: Color3,
}

local HorseRarity = {}

HorseRarity.Order = { "Bronze", "Silver", "Gold", "Champion", "Royal", "Legend" } :: { RarityId }

HorseRarity.Definitions = {
	Bronze = {
		Id = "Bronze",
		DisplayName = "브론즈",
		SpawnWeight = 45,
		StealHoldSeconds = 2,
		EscapeSeconds = 45,
		MinimumObstacleGapSeconds = 2,
		Color = Color3.fromRGB(184, 115, 51),
	},
	Silver = {
		Id = "Silver",
		DisplayName = "실버",
		SpawnWeight = 28,
		StealHoldSeconds = 2,
		EscapeSeconds = 55,
		MinimumObstacleGapSeconds = 1.8,
		Color = Color3.fromRGB(192, 192, 192),
	},
	Gold = {
		Id = "Gold",
		DisplayName = "골드",
		SpawnWeight = 15,
		StealHoldSeconds = 2,
		EscapeSeconds = 65,
		MinimumObstacleGapSeconds = 1.6,
		Color = Color3.fromRGB(255, 205, 64),
	},
	Champion = {
		Id = "Champion",
		DisplayName = "챔피언",
		SpawnWeight = 8,
		StealHoldSeconds = 2,
		EscapeSeconds = 75,
		MinimumObstacleGapSeconds = 1.4,
		Color = Color3.fromRGB(104, 174, 255),
	},
	Royal = {
		Id = "Royal",
		DisplayName = "로얄",
		SpawnWeight = 3,
		StealHoldSeconds = 2,
		EscapeSeconds = 90,
		MinimumObstacleGapSeconds = 1.2,
		Color = Color3.fromRGB(182, 112, 255),
	},
	Legend = {
		Id = "Legend",
		DisplayName = "레전드",
		SpawnWeight = 1,
		StealHoldSeconds = 2,
		EscapeSeconds = 105,
		MinimumObstacleGapSeconds = 1,
		Color = Color3.fromRGB(255, 93, 93),
	},
} :: { [RarityId]: RarityDefinition }

function HorseRarity.choose(random: Random): RarityDefinition
	local roll = random:NextInteger(1, 100)
	local total = 0

	for _, rarityId in HorseRarity.Order do
		local definition = HorseRarity.Definitions[rarityId]
		total += definition.SpawnWeight
		if roll <= total then
			return definition
		end
	end

	return HorseRarity.Definitions.Bronze
end

function HorseRarity.get(rarityId: string?): RarityDefinition
	local definition = rarityId and HorseRarity.Definitions[rarityId :: RarityId]
	return definition or HorseRarity.Definitions.Bronze
end

return HorseRarity

