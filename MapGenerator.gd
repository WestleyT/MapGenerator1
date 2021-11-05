extends Node2D

onready var tilemap = $TileMap
onready var textField = $MarginContainer/VBoxContainer/HBoxContainer/LineEdit
onready var label = $MarginContainer/VBoxContainer/Label
onready var windOption = $MarginContainer/VBoxContainer/HBoxContainer3/OptionButton

var width : int = 60
var height : int = 34
var percentOcean : float = 0.6
var percentMountainSeed : int = 1
var mountainPercent : float = 0.15
var mountainSmoothPasses : int = 2
var totalRivers = 4
var ogCitiesNumber: int = 8
var numberOfCities : int = 8
var windDir = 0 #for rain shadow on moutains, 0 = on eastern side, 1 = on western side 

var neighborDirections = [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1),
	Vector2(1, -1), Vector2(-1, 1)
]
var neighborDirectionsManhatten = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

var landTilesArray = []
var waterTilesArray = []
var mountainTilesArray = []
var desertTilesArray = []
var cityTilesArray = []
var riverArray = []
var arrayOfArrays = [mountainTilesArray, landTilesArray, waterTilesArray, desertTilesArray, cityTilesArray]

var rng = RandomNumberGenerator.new()

var smoothPasses : int = 4
enum tileType {mountain, grass, water, desert, city, hill, pink, black, navy}

func _ready():
	windOption.add_item("Westerly")
	windOption.add_item("Easterly")
	windOption.select(0)
	
	$MarginContainer/VBoxContainer/HBoxContainer2/CitiesSlider.set_value(numberOfCities)
	$MarginContainer/VBoxContainer/HBoxContainer2/CitySliderLabel.set_text('Cities: ' + str(numberOfCities))
	
#randomly seed the map with about 60/40 ocean/land
func generateLand():
	for x in range(0, width):
		for y in range(0, height):
			var random = rng.randf()
			if random >= percentOcean:
				tilemap.set_cell(x, y, tileType.grass)
				landTilesArray.append(Vector2(x, y))
			else: 
				tilemap.set_cell(x, y, tileType.water)
				waterTilesArray.append(Vector2(x, y))
				
#pass through the map and change water tiles to land if enough neighbors are also land
func smoothMap():
	for x in range(0, width):
		for y in range(0, height):
			if tilemap.get_cell(x, y) == tileType.water:
				var neighborLands : int = 0
				var coord = Vector2(x, y)
				for direction in neighborDirections:
					var neighborTile = coord + direction
					if tilemap.get_cellv(neighborTile) == tileType.grass:
						neighborLands += 1
				if neighborLands > 4:
					tilemap.set_cellv(coord, tileType.grass)
					arraySwap(landTilesArray, waterTilesArray, coord)
				else:
					tilemap.set_cellv(coord, tileType.water)
					arraySwap(waterTilesArray, landTilesArray, coord)

func generateMountains():
	#seed random mountains on some land tiles
	for landTile in landTilesArray:
		var random = rng.randi_range(0, 100)
		if random <= percentMountainSeed:
			tilemap.set_cellv(landTile, tileType.mountain)
			arraySwap(mountainTilesArray, landTilesArray, landTile)
			
	#for each mountain, add some more next to it
	for mountainTile in mountainTilesArray:
		for direction in neighborDirections:
			var targetTile = mountainTile + direction
			if tilemap.get_cellv(targetTile) == tileType.grass:
				if rng.randf() <= mountainPercent:
					tilemap.set_cellv(targetTile, tileType.mountain)
					arraySwap(mountainTilesArray, landTilesArray, targetTile)
					
	#eliminate solo mountains
	for i in mountainSmoothPasses:
		for mountainTile in mountainTilesArray:
			var adjacentMountains : int = 0
			for direction in neighborDirections:
				var targetTile = mountainTile + direction
				if tilemap.get_cellv(targetTile) == tileType.mountain:
					adjacentMountains += 1
			if adjacentMountains == 0:
				tilemap.set_cellv(mountainTile, tileType.grass)
				arraySwap(landTilesArray, mountainTilesArray, mountainTile)

func generateDeserts():
	var rainShadowNeighbors = []
	if windDir == 0:
		rainShadowNeighbors = [Vector2(1, 0), Vector2(1, 1), Vector2(1, -1)]
	if windDir == 1:
		rainShadowNeighbors = [Vector2(-1, 0), Vector2(-1, 1), Vector2(-1, -1)]
	for mountainTile in mountainTilesArray:
		for dir in rainShadowNeighbors:
			var targetTile = dir + mountainTile
			if tilemap.get_cellv(targetTile) == tileType.grass:
				tilemap.set_cellv(targetTile, tileType.desert)
				arraySwap(desertTilesArray, landTilesArray, targetTile)
				
	var tempDesertTiles = []
	for desertTile in desertTilesArray:
		var targetTile = desertTile + Vector2(1, 0)
		if tilemap.get_cellv(targetTile) == tileType.grass:
			var adjacentWater = 0
			for dir in rainShadowNeighbors:
				var adjTile = targetTile + dir
				if tilemap.get_cellv(adjTile) == tileType.water:
					adjacentWater += 1
			if adjacentWater == 0:
				tilemap.set_cellv(targetTile, tileType.desert)
				tempDesertTiles.append(targetTile)
				
	for tile in tempDesertTiles:
		arraySwap(desertTilesArray, landTilesArray, tile)

func generateRivers():
	for i in totalRivers:
		var riverCoords = []
		#pick a random mountain to start with, then head towards the sea
		var nextTile = mountainTilesArray[rng.randi_range(0, mountainTilesArray.size() - 1)]
		var hitOcean : bool = false
		while hitOcean == false:
			var randIndex = rng.randi_range(0, neighborDirectionsManhatten.size() - 1)
			nextTile = nextTile + neighborDirectionsManhatten[randIndex]
			if riverCoords.has(nextTile):
				nextTile += Vector2(0, -1)
			if tilemap.get_cellv(nextTile) != tileType.water:
				riverCoords.append(nextTile)
			else: 
				hitOcean = true
				
		for coord in riverCoords:
			tilemap.set_cellv(coord, tileType.pink)
			
		riverArray.append(riverCoords)
	
func generateCities():
	for i in numberOfCities:
		var randomLandTile = landTilesArray[rng.randi_range(0, landTilesArray.size() - 1)]
		tilemap.set_cellv(randomLandTile, tileType.city)
		arraySwap(cityTilesArray, landTilesArray, randomLandTile)
		
	
func arraySwap(addArray, removeArray, coord):
	if !addArray.has(coord):
		addArray.append(coord)
		var removeIndex = removeArray.find(coord)
		removeArray.remove(removeIndex)
		
			
func clearAll():
	tilemap.clear()
	
	for a in arrayOfArrays:
		a.clear()
	
func _on_Button_pressed():
	clearAll()
	
	var enteredSeed = textField.get_text()
	if enteredSeed != '':
		var hashedSeed : int = hash(enteredSeed)
		rng.set_seed(hashedSeed)
	else:
		rng.randomize()
		
	label.set_text('Seed: ' + str(rng.get_state())) 
	generateLand()
	for i in smoothPasses:
		smoothMap()
	generateMountains()
	generateDeserts()
	generateCities()


func _on_ClearButton_pressed():
	textField.clear()
	windOption.select(0)
	numberOfCities = ogCitiesNumber
	$MarginContainer/VBoxContainer/HBoxContainer2/CitiesSlider.set_value(numberOfCities)
	$MarginContainer/VBoxContainer/HBoxContainer2/CitySliderLabel.set_text("Cities: " + str(numberOfCities))


func _on_OptionButton_item_selected(index):
	windDir = index


func _on_CitiesSlider_value_changed(value):
	numberOfCities = value
	$MarginContainer/VBoxContainer/HBoxContainer2/CitySliderLabel.set_text("Cities: " + str(value))
