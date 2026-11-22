--!strict
--!optimize 2
-- The package's one entry: every module and type AnimLayers hands out. Everything in the package is
-- shared: it runs on the server and on the client.
local PlayEndedReason = require("./common/playEndedReason/playEndedReason")
local LayerController = require("./controllers/layerController/layerController")
local ClipDefinitionTypes = require("./types/def/playback/clipDefinition/public")
local LayerControllerTypes = require("./types/controllers/layerController/layerController/public")
local PlayEndedReasonTypes = require("./types/def/playback/playEndedReason/public")
local ClipDefinition = require("./utils/clipDefinition/clipDefinition")

export type ClipDefinition = ClipDefinitionTypes.ClipDefinition
export type LayerDefinition = LayerControllerTypes.LayerDefinition
export type LayerController = LayerControllerTypes.LayerController
export type LayerControllerOwned = LayerControllerTypes.LayerControllerOwned
export type PlayEndedReason = PlayEndedReasonTypes.PlayEndedReason
export type Unsubscribe = LayerControllerTypes.Unsubscribe

type ClipDefinitionModule = ClipDefinition.ClipDefinitionModule
type LayerControllerModule = LayerController.LayerControllerModule
type PlayEndedReasonModule = PlayEndedReason.PlayEndedReasonModule
type AnimLayersModule = {
	read common: { read playEndedReason: PlayEndedReasonModule },
	read controllers: { read layerController: LayerControllerModule },
	read utils: { read clipDefinition: ClipDefinitionModule },
}

local module: AnimLayersModule = table.freeze({
	common = table.freeze({ playEndedReason = PlayEndedReason }),
	controllers = table.freeze({ layerController = LayerController }),
	utils = table.freeze({ clipDefinition = ClipDefinition }),
})
return module
