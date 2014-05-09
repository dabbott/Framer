{_} = require "./Underscore"
Utils = require "./Utils"

ChromeAlert = """
Importing layers is currently only supported on Safari. If you really want it to work with Chrome quit it, open a terminal and run:
open -a Google\ Chrome -–allow-file-access-from-files
"""

class exports.Importer

	constructor: (@path, @extraLayerProperties={}) ->

		@paths =
			layerInfo: Utils.pathJoin @path, "layers.json"
			images: Utils.pathJoin @path, "images"
			documentName: @path.split("/").pop()

		@_createdLayers = []
		@_createdLayersByName = {}

	load: ->

		layersByName = {}
		layerInfo = @_loadlayerInfo()
		
		# Pass one. Create all layers build the hierarchy
		layerInfo.map (layerItemInfo) =>
			@_createLayer layerItemInfo

		# Pass two. Adjust position on screen for all layers
		# based on the hierarchy.
		for layer in @_createdLayers
			@_correctLayer layer

		# Pass three, insert the layers into the dom
		# (they were not inserted yet because of the shadow keyword)
		for layer in @_createdLayers
			if not layer.superLayer
				layer.superLayer = null

		@_createdLayersByName

	_loadlayerInfo: ->

		# Chrome is a pain in the ass and won't allow local file access
		# therefore I add a .js file which adds the data to 
		# window.__imported__["<path>"]

		importedKey = "#{@paths.documentName}/layers.json.js"

		if window.__imported__?.hasOwnProperty importedKey
			return window.__imported__[importedKey]

		# # For now this does not work in Chrome and we throw an error
		# try
		# 	return Framer.Utils.domLoadJSONSync @paths.layerInfo
		# catch e
		# 	if Utils.isChrome
		# 		alert ChromeAlert
		# 	else
		# 		throw e

		return Framer.Utils.domLoadJSONSync @paths.layerInfo

	_createLayer: (info, superLayer) ->
		
		LayerClass = Layer

		layerInfo =
			shadow: true
			name: info.name
			frame: info.layerFrame
			clip: false
			backgroundColor: null
			visible: info.visible ? true

		_.extend layerInfo, @extraLayerProperties

		# Most layers will have an image, add that here
		if info.image
			layerInfo.frame = info.image.frame
			layerInfo.image = Utils.pathJoin @path, info.image.path
			
		# If there is a mask on this layer group, take it's frame
		if info.maskFrame
			layerInfo.frame = info.maskFrame
			layerInfo.clip = true

		# Todo: smart stuff for paging and scroll views

		# Figure out what the super layer should be. If this layer has a contentLayer
		# (like a scroll view) we attach it to that instead.
		if superLayer?.contentLayer
			layerInfo.superLayer = superLayer.contentLayer
		else if superLayer
			layerInfo.superLayer = superLayer

		# We can create the layer here
		layer = new LayerClass layerInfo
		layer.name = layerInfo.name

		# A layer without an image, mask or sublayers should be zero
		if not layer.image and not info.children.length and not info.maskFrame
			layer.frame = new Frame

		info.children.reverse().map (info) => @_createLayer info, layer

		# TODODODODOD
		if not layer.image and not info.maskFrame
			layer.frame = layer.contentFrame()

		layer._info = info

		@_createdLayers.push layer
		@_createdLayersByName[layer.name] = layer

	_correctLayer: (layer) ->

		traverse = (layer) ->

			if layer.superLayer
				layer.frame = Utils.convertPoint layer.frame, null, layer.superLayer

			for subLayer in layer.subLayers
				traverse subLayer

		if not layer.superLayer
			traverse layer

exports.Importer.load = (path) ->
	importer = new exports.Importer path
	importer.load()