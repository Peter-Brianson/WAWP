extends Resource
class_name CardTextureAtlas

@export_group("Atlas")
@export var atlas_texture: Texture2D
@export var columns: int = 13
@export var rows: int = 5
@export var card_width: int = 0
@export var card_height: int = 0

@export_group("Layout")
@export var first_card_index: int = 0
@export var first_back_index: int = 52
@export var default_back_variant: int = 0

@export_group("Grid Card Layout")
@export var use_row_column_card_layout: bool = true
@export var first_card_row: int = 0
@export var first_card_column: int = 1
@export var suit_row_stride: int = 1

@export_group("Card Order")
@export var rank_order: Array[String] = [
	"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"
]

@export var suit_order: Array[String] = [
	"♠", "♥", "♦", "♣"
]


func get_card_texture(card: Dictionary) -> Texture2D:
	if atlas_texture == null:
		return null

	var rank: String = String(card.get("rank", ""))
	var suit: String = _normalize_suit(String(card.get("suit", "")))

	var rank_index: int = rank_order.find(rank)
	var suit_index: int = suit_order.find(suit)

	if rank_index < 0:
		push_warning("CardTextureAtlas could not find rank: %s" % rank)
		return get_back_texture(default_back_variant)

	if suit_index < 0:
		push_warning("CardTextureAtlas could not find suit: %s" % suit)
		return get_back_texture(default_back_variant)

	if use_row_column_card_layout:
		var row: int = first_card_row + suit_index * suit_row_stride
		var column: int = first_card_column + rank_index
		var card_index: int = row * columns + column
		return get_index_texture(card_index)

	var fallback_index: int = first_card_index + suit_index * rank_order.size() + rank_index
	return get_index_texture(fallback_index)


func get_back_texture(back_variant: int = -1) -> Texture2D:
	if back_variant < 0:
		back_variant = default_back_variant

	var card_index: int = first_back_index + back_variant
	return get_index_texture(card_index)


func get_index_texture(index: int) -> Texture2D:
	if atlas_texture == null:
		return null

	var size: Vector2i = get_card_pixel_size()
	if size.x <= 0 or size.y <= 0:
		return null

	var col: int = index % columns
	var row: int = index / columns

	if row >= rows:
		push_warning("CardTextureAtlas index outside atlas: %d" % index)
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = atlas_texture
	atlas.region = Rect2(
		float(col * size.x),
		float(row * size.y),
		float(size.x),
		float(size.y)
	)

	return atlas


func get_card_pixel_size() -> Vector2i:
	if card_width > 0 and card_height > 0:
		return Vector2i(card_width, card_height)

	if atlas_texture == null:
		return Vector2i.ZERO

	if columns <= 0 or rows <= 0:
		return Vector2i.ZERO

	var atlas_size: Vector2i = atlas_texture.get_size()
	return Vector2i(
		atlas_size.x / columns,
		atlas_size.y / rows
	)


func _normalize_suit(value: String) -> String:
	var lowered: String = value.to_lower()

	match lowered:
		"spade", "spades", "s":
			return "♠"
		"heart", "hearts", "h":
			return "♥"
		"diamond", "diamonds", "d":
			return "♦"
		"club", "clubs", "c":
			return "♣"

	return value
