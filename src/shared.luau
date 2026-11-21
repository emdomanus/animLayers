--!strict
--!optimize 2
-- The package's one entry: every module and type AnimLayers hands out. Everything in the package is
-- shared: it runs on the server and on the client.
local LayerController = require("./controllers/layerController/layerController")
local ClipDefinitionTypes = require("./types/def/playback/clipDefinition/public")
local LayerControllerTypes = require("./types/controllers/layerController/layerController/public")
local ClipDefinition = require("./utils/clipDefinition/clipDefinition")

export type ClipDefinition = ClipDefinitionTypes.ClipDefinition
export type LayerDefinition = LayerControllerTypes.LayerDefinition
export type LayerController = LayerControllerTypes.LayerController
export type LayerControllerOwned = LayerControllerTypes.LayerControllerOwned
export type Unsubscribe = LayerControllerTypes.Unsubscribe

type ClipDefinitionModule = ClipDefinition.ClipDefinitionModule
type LayerControllerModule = LayerController.LayerControllerModule
type AnimLayersModule = {
	read controllers: { read layerController: LayerControllerModule },
	read utils: { read clipDefinition: ClipDefinitionModule },
}

local module: AnimLayersModule = table.freeze({
	controllers = table.freeze({ layerController = LayerController }),
	utils = table.freeze({ clipDefinition = ClipDefinition }),
})
return module
