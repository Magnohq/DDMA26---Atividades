extends Area2D

# Variável declarada para que o script a reconheça
var hud: Node 

func _ready() -> void:
	# Busca o nó HUD na cena principal
	hud = get_tree().current_scene.get_node("HUD")

func _on_body_entered(body: Node2D) -> void:
	print("Algo entrou na área: ", body.name)
	
	if body.name == "Player":
		print("Player detectado! Atualizando HUD...")
		if hud:
			hud.adicionar_item()
		else:
			print("ERRO: HUD não encontrada!")
			
		# Agora o Godot vai encontrar essa função logo abaixo
		reposicionar()

# A função reposicionar que estava faltando
func reposicionar() -> void:
	var tela = get_viewport_rect().size
	# Gera coordenadas aleatórias dentro da tela com margem de 40px
	var nova_x = randf_range(40, tela.x - 40)
	var nova_y = randf_range(40, tela.y - 40)
	global_position = Vector2(nova_x, nova_y)
