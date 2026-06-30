extends Control

@onready var expressao_label = $VBoxContainer/PanelContainer/VBoxContainer/expressao_label
@onready var resultado_label = $VBoxContainer/PanelContainer/VBoxContainer/resultado_label
@onready var painel = $VBoxContainer/PanelContainer

var numero_atual: String = ""
var numero_anterior: float = 0.0
var operacao_atual: String = ""
var aguardando_segundo_numero: bool = false

var cores = {
	"+": Color("#4CAF50"),
	"−": Color("#FFC107"),
	"×": Color("#9C27B0"),
	"÷": Color("#2196F3"),
	"C": Color("#424242"),
	"ERRO": Color("#F44336")
}

func _ready() -> void:
	for botao in get_tree().get_nodes_in_group("botoes"):
		botao.pressed.connect(_on_button_pressed.bind(botao.text))
	resetar_calculadora()

func _on_button_pressed(valor: String) -> void:
	if valor.is_valid_float():
		digito_pressionado(valor)
	elif valor in ["+", "−", "×", "÷"]:
		operacao_pressionada(valor)
	elif valor == "=":
		calcular_resultado()
	elif valor == "C":
		resetar_calculadora()

func digito_pressionado(digito: String) -> void:
	if aguardando_segundo_numero:
		numero_atual = ""
		aguardando_segundo_numero = false
	
	numero_atual += digito
	resultado_label.text = numero_atual

func operacao_pressionada(operacao: String) -> void:
	if numero_atual != "":
		numero_anterior = numero_atual.to_float()
	
	operacao_atual = operacao
	aguardando_segundo_numero = true
	expressao_label.text = str(numero_anterior) + " " + operacao_atual
	mudar_cor(cores[operacao])

func calcular_resultado() -> void:
	if operacao_atual == "" or numero_atual == "":
		return
		
	var segundo_numero = numero_atual.to_float()
	var resultado: float = 0.0
	
	if operacao_atual == "÷" and segundo_numero == 0.0:
		resultado_label.text = "Erro!"
		mudar_cor(cores["ERRO"])
		return
		
	match operacao_atual:
		"+": resultado = numero_anterior + segundo_numero
		"−": resultado = numero_anterior - segundo_numero
		"×": resultado = numero_anterior * segundo_numero
		"÷": resultado = numero_anterior / segundo_numero
		
	expressao_label.text = str(numero_anterior) + " " + operacao_atual + " " + str(segundo_numero) + " ="
	resultado_label.text = str(resultado)
	numero_atual = str(resultado)
	aguardando_segundo_numero = true
	operacao_atual = ""

func resetar_calculadora() -> void:
	numero_atual = ""
	numero_anterior = 0.0
	operacao_atual = ""
	aguardando_segundo_numero = false
	expressao_label.text = ""
	resultado_label.text = "0"
	mudar_cor(cores["C"])

func mudar_cor(cor: Color) -> void:
	var estilo = painel.get_theme_stylebox("panel").duplicate()
	estilo.bg_color = cor
	painel.add_theme_stylebox_override("panel", estilo)
