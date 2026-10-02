@tool
class_name AnimalSpecies
extends Resource
## What makes one animal look different from another: colours, ear shape, tail
## shape, snout length. `AnimalModel` builds a character from one of these.
##
## Adding an animal later (cat, bunny, fox ...) means making a new species here,
## not new model code: `AnimalSpecies.dog()` is the only one the game ships with.

enum EarStyle { FLOPPY, POINTY, ROUND }
enum TailStyle { CURLED, LONG, STUB }

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
