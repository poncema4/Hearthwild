@tool
class_name AnimalSpecies
extends Resource
## What makes one animal look different from another: colours, ear shape, tail
## shape, snout length. `AnimalModel` builds a character from one of these.
##
## Adding an animal later (cat, bunny, fox ...) means making a new species here,
## not new model code: `AnimalSpecies.dog()` is the only one the game ships with.

enum EarStyle { FLOPPY, POINTY, ROUND, TALL }
enum TailStyle { CURLED, LONG, STUB }

## Stable id used in save files and the character screen (never rename once shipped).
@export var id: StringName = &"dog"
@export var species_name := "Dog"
@export var fur_color := Color(0.87, 0.63, 0.36)
## Ears and the patch around one eye.
@export var accent_color := Color(0.60, 0.38, 0.21)
## Snout, belly, paws and the tail tip.
@export var belly_color := Color(0.98, 0.91, 0.76)
@export var nose_color := Color(0.17, 0.11, 0.12)
@export var eye_color := Color(0.10, 0.07, 0.08)
@export var cheek_color := Color(1.0, 0.62, 0.66)
@export var ear_style := EarStyle.FLOPPY
@export var tail_style := TailStyle.CURLED
## 1.0 = a short, friendly muzzle. Larger sticks out more (a longer-nosed animal).
@export_range(0.6, 1.6) var snout_length := 1.0
@export var eye_patch := true


## The friendly golden dog the game starts with.
static func dog() -> AnimalSpecies:
	return AnimalSpecies.new()


static func cat() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"cat"
	s.species_name = "Cat"
	s.fur_color = Color(0.66, 0.68, 0.76)
	s.accent_color = Color(0.40, 0.42, 0.50)
	s.belly_color = Color(0.97, 0.96, 0.95)
	s.nose_color = Color(0.92, 0.55, 0.62)
	s.eye_color = Color(0.10, 0.28, 0.14)
	s.ear_style = EarStyle.POINTY
	s.tail_style = TailStyle.LONG
	s.snout_length = 0.75
	s.eye_patch = false
	return s


static func bunny() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"bunny"
	s.species_name = "Bunny"
	s.fur_color = Color(0.97, 0.94, 0.91)
	s.accent_color = Color(0.96, 0.78, 0.82)
	s.belly_color = Color(1.0, 0.99, 0.97)
	s.nose_color = Color(0.95, 0.58, 0.66)
	s.ear_style = EarStyle.TALL
	s.tail_style = TailStyle.STUB
	s.snout_length = 0.7
	s.eye_patch = false
	return s


## Every animal the player can pick, in the order the character screen shows them.
static func all() -> Array[AnimalSpecies]:
	return [dog(), cat(), bunny()]


## The species with this id (the dog if unknown, so an old or edited save never breaks).
static func by_id(species_id: StringName) -> AnimalSpecies:
	for species in all():
		if species.id == species_id:
			return species
	return dog()
