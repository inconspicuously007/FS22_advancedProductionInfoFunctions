AdvancedProductionChainManager = {}

function AdvancedProductionChainManager:distributeGoods()
	if not self.isServer then
		return
	end

	for _, farmTable in pairs(self.farmIds) do
		for i = 1, #farmTable.productionPoints do
			local distributingProdPoint = farmTable.productionPoints[i]			
			
			for fillTypeIdToDistribute in pairs(distributingProdPoint.outputFillTypeIdsAutoDeliver) do
				local amountToDistribute = distributingProdPoint.storage:getFillLevel(fillTypeIdToDistribute)
				
				if amountToDistribute > 0 then
					local prodPointsInDemandTmp = farmTable.inputTypeToProductionPoints[fillTypeIdToDistribute] or {}
					local prodPointsInDemand = {}
					local totalProductions = 0
					local prodPointActiveProductions = {}					
					
					for x = 1, #prodPointsInDemandTmp do
						local prodPoint = prodPointsInDemandTmp[x]
						if prodPointActiveProductions[prodPoint] == nil then
							prodPointActiveProductions[prodPoint] = 0
						end
						local prodPointProductions = prodPoint.inputTypeToProduction[fillTypeIdToDistribute] or {}
						
						for p = 1, #prodPointProductions do
							local check = false
							if prodPointProductions[p].status ~= ProductionPoint.PROD_STATUS.INACTIVE then
							--and prodPointProductions[p].status ~= ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
								table.addElement(prodPointsInDemand, prodPoint)
								
								prodPointActiveProductions[prodPoint] = prodPointActiveProductions[prodPoint] + 1
								totalProductions = totalProductions + 1										
							end
						end
					end
					
					local totalFreeCapacity = 0

					for n = 1, #prodPointsInDemand do
						totalFreeCapacity = totalFreeCapacity + prodPointsInDemand[n].storage:getFreeCapacity(fillTypeIdToDistribute, true)
					end
					
					if totalFreeCapacity > 0 then
						for n = 1, #prodPointsInDemand do
							local prodPointInDemand = prodPointsInDemand[n]
							local maxAmountToReceive = prodPointInDemand.storage:getFreeCapacity(fillTypeIdToDistribute, true)

							if maxAmountToReceive > 0 then
								--- old calculation ---
								--local amountToTransfer = math.min(maxAmountToReceive, amountToDistribute * maxAmountToReceive / totalFreeCapacity)
								--- new calculationa ---
								local amountToTransfer = math.min(maxAmountToReceive, math.floor(amountToDistribute * prodPointActiveProductions[prodPointInDemand] / totalProductions))
								
								local distanceSourceToTarget = calcDistanceFrom(distributingProdPoint.owningPlaceable.rootNode, prodPointInDemand.owningPlaceable.rootNode)
								local transferCosts = amountToTransfer * distanceSourceToTarget * ProductionPoint.DIRECT_DELIVERY_PRICE

								g_currentMission:addMoney(-transferCosts, prodPointInDemand.ownerFarmId, MoneyType.PRODUCTION_COSTS, true)
								prodPointInDemand.storage:setFillLevel(prodPointInDemand.storage:getFillLevel(fillTypeIdToDistribute) + amountToTransfer, fillTypeIdToDistribute)
								distributingProdPoint.storage:setFillLevel(distributingProdPoint.storage:getFillLevel(fillTypeIdToDistribute) - amountToTransfer, fillTypeIdToDistribute)
							end
						end
					end
				end
			end
		end
	end
end

ProductionChainManager.distributeGoods = Utils.overwrittenFunction(ProductionChainManager.distributeGoods, AdvancedProductionChainManager.distributeGoods)