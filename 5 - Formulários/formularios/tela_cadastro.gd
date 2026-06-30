extends Control

@onready var input_nome = $VBoxContainer/InputNome
@onready var input_email = $VBoxContainer/InputEmail
@onready var input_senha = $VBoxContainer/InputSenha
@onready var input_confirmar_senha = $VBoxContainer/InputConfirmarSenha
@onready var botao_cadastrar = $VBoxContainer/BotaoCadastrar
@onready var label_mensagem = $VBoxContainer/LabelMensagem

func _ready():
	botao_cadastrar.pressed.connect(_on_botao_cadastrar_pressed)

func _on_botao_cadastrar_pressed():
	var nome = input_nome.text.strip_edges()
	var email = input_email.text.strip_edges()
	var senha = input_senha.text
	var confirmar = input_confirmar_senha.text

	if nome.is_empty():
		exibir_mensagem("Nome não pode estar em branco.", Color.RED)
		return
	if email.is_empty() or not ("@" in email and "." in email):
		exibir_mensagem("E-mail inválido.", Color.RED)
		return
	if senha.length() < 6:
		exibir_mensagem("A senha deve ter no mínimo 6 caracteres.", Color.RED)
		return
	if senha != confirmar:
		exibir_mensagem("As senhas não coincidem.", Color.RED)
		return

	exibir_mensagem("Sucesso!", Color.GREEN)

func exibir_mensagem(texto: String, cor: Color):
	label_mensagem.text = texto
	label_mensagem.add_theme_color_override("font_color", cor)
