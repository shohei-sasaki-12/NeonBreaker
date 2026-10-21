--!strict

local WeaponBallistics = {}

-- Uniform directions over a cone. Only the server chooses pellet randomness.
function WeaponBallistics.GetDirections(direction: Vector3, count: number, spread: number, random: Random): { Vector3 }
	local forward = direction.Unit
	local basis = CFrame.lookAt(Vector3.zero, forward)
	local minCosine = math.cos(math.rad(spread))
	local result: { Vector3 } = {}
	for _ = 1, count do
		if spread <= 0 then
			table.insert(result, forward)
		else
			local cosine = random:NextNumber(minCosine, 1)
			local sine = math.sqrt(math.max(0, 1 - cosine * cosine))
			local angle = random:NextNumber(0, 2 * math.pi)
			table.insert(result, basis:VectorToWorldSpace(Vector3.new(sine * math.cos(angle), sine * math.sin(angle), -cosine)))
		end
	end
	return result
end

return WeaponBallistics
