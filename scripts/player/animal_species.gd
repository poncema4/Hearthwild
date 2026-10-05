@tool
class_name AnimalSpecies
extends Resource
## What makes one animal look different from another: colours, ear shape, tail
## shape, snout length. `AnimalModel` builds a character from one of these.
##
## Adding an animal means making a new species here, not new model code. The game ships dog, cat, bunny, fox, bear, panda, pig, mouse and
## raccoon, all built from the same ear styles, tail styles, colours and snout lengths.

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


static func fox() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"fox"
	s.species_name = "Fox"
	s.fur_color = Color(0.93, 0.47, 0.15)
	s.accent_color = Color(0.30, 0.15, 0.09)  # dark ear backs, like a real fox's black "socks"
	s.belly_color = Color(0.99, 0.95, 0.87)
	s.nose_color = Color(0.10, 0.08, 0.08)
	s.eye_color = Color(0.20, 0.12, 0.05)
	s.ear_style = EarStyle.POINTY
	s.tail_style = TailStyle.LONG
	s.snout_length = 1.2
	s.eye_patch = false
	return s


static func bear() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"bear"
	s.species_name = "Bear"
	s.fur_color = Color(0.55, 0.35, 0.21)
	s.accent_color = Color(0.40, 0.24, 0.13)
	s.belly_color = Color(0.84, 0.66, 0.48)
	s.nose_color = Color(0.13, 0.09, 0.08)
	s.ear_style = EarStyle.ROUND
	s.tail_style = TailStyle.STUB
	s.snout_length = 0.95
	s.eye_patch = false
	return s


static func panda() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"panda"
	s.species_name = "Panda"
	s.fur_color = Color(0.97, 0.97, 0.98)
	s.accent_color = Color(0.11, 0.11, 0.13)  # black ears and eye patch
	s.belly_color = Color(0.99, 0.99, 1.0)
	s.nose_color = Color(0.10, 0.10, 0.11)
	s.ear_style = EarStyle.ROUND
	s.tail_style = TailStyle.STUB
	s.snout_length = 0.8
	s.eye_patch = true
	return s


static func pig() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"pig"
	s.species_name = "Pig"
	s.fur_color = Color(0.98, 0.74, 0.77)
	s.accent_color = Color(0.93, 0.56, 0.63)
	s.belly_color = Color(1.0, 0.86, 0.88)
	s.nose_color = Color(0.91, 0.52, 0.60)
	s.cheek_color = Color(1.0, 0.55, 0.60)
	s.ear_style = EarStyle.FLOPPY
	s.tail_style = TailStyle.CURLED
	s.snout_length = 1.05
	s.eye_patch = false
	return s


static func mouse() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"mouse"
	s.species_name = "Mouse"
	s.fur_color = Color(0.74, 0.74, 0.79)
	s.accent_color = Color(0.96, 0.72, 0.78)  # pink inside the big round ears
	s.belly_color = Color(0.96, 0.93, 0.93)
	s.nose_color = Color(0.95, 0.60, 0.68)
	s.ear_style = EarStyle.ROUND
	s.tail_style = TailStyle.LONG
	s.snout_length = 0.7
	s.eye_patch = false
	return s


static func raccoon() -> AnimalSpecies:
	var s := AnimalSpecies.new()
	s.id = &"raccoon"
	s.species_name = "Raccoon"
	s.fur_color = Color(0.56, 0.58, 0.62)
	s.accent_color = Color(0.19, 0.19, 0.23)  # the bandit mask
	s.belly_color = Color(0.83, 0.85, 0.87)
	s.nose_color = Color(0.10, 0.10, 0.12)
	s.ear_style = EarStyle.ROUND
	s.tail_style = TailStyle.LONG
	s.snout_length = 1.0
	s.eye_patch = true
	return s


## Every animal the player can pick, in the order the character screen shows them. New animals go at the END (saved profiles use ids, but the
## order is what the picker cycles through and what tests rely on for the first three).
static func all() -> Array[AnimalSpecies]:
	return [dog(), cat(), bunny(), fox(), bear(), panda(), pig(), mouse(), raccoon()]


## The species with this id (the dog if unknown, so an old or edited save never breaks).
static func by_id(species_id: StringName) -> AnimalSpecies:
	for species in all():
		if species.id == species_id:
			return species
	return dog()
