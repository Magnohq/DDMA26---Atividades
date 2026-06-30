extends Control

# Pega a referência da barra de progresso.
# ATENÇÃO: Ajuste o caminho abaixo para bater EXATAMENTE com o nome 
# dos nós que você criou na sua aba "Scene".
@onready var progress_bar = $MainContainer/LayoutVertical/BarraProgresso

func _ready():
	# 1. Garante que a barra comece zerada quando o jogo rodar
	progress_bar.value = 0

	# 2. Cria o objeto Tween dinamicamente (Padrão do Godot 4)
	var tween = create_tween()

	# 3. Configura a Transição e o Easing (Exigência do seu checklist)
	# TRANS_LINEAR faz a velocidade ser constante. 
	# Você pode trocar para TRANS_ELASTIC ou TRANS_BOUNCE para efeitos divertidos.
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# EASE_IN_OUT suaviza a entrada e a saída da animação.
	tween.set_ease(Tween.EASE_IN_OUT)

	# 4. Executa a animação de fato
	# Lê-se: Animar no objeto 'progress_bar', a propriedade "value", até o valor 100.0, durante 2.0 segundos.
	tween.tween_property(progress_bar, "value", 100.0, 2.0)
