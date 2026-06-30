extends CanvasLayer

# Contador de itens coletados
var total_itens: int = 0

func adicionar_item() -> void:
	total_itens += 1
	# Atualiza o texto do Label na tela
	$Contador.text = "Itens: " + str(total_itens)
