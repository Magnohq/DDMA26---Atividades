extends Node2D

# Referências aos nós da interface
@onready var input_id = $VBoxContainer/HBoxContainer/InputID
@onready var btn_buscar = $VBoxContainer/HBoxContainer/BtnBuscar
@onready var label_status = $VBoxContainer/LabelStatus

@onready var label_id = $VBoxContainer/LabelID
@onready var label_nome = $VBoxContainer/LabelNome
@onready var label_pai = $VBoxContainer/LabelPai
@onready var label_mae = $VBoxContainer/LabelMae

@onready var scroll_vbox = $VBoxContainer/ScrollContainer/VBoxJutsus
@onready var http_request = $HTTPRequest

const BASE_URL = "https://dattebayo-api.onrender.com/characters/"

func _ready():
	# Conectando os sinais via código
	btn_buscar.pressed.connect(_on_btn_buscar_pressed)
	http_request.request_completed.connect(_on_http_request_completed)
	
	_limpar_interface()
	label_status.text = "Digite um ID para buscar."

func _on_btn_buscar_pressed():
	var id_texto = input_id.text.strip_edges()
	
	if id_texto.is_empty():
		label_status.text = "Por favor, digite o ID do personagem."
		return

	# DESAFIO BÔNUS: Desabilitar o botão para evitar múltiplas chamadas
	btn_buscar.disabled = true
	label_status.text = "Buscando personagem..."
	
	# Limpa os dados da busca anterior
	_limpar_interface()
	
	# Fazendo a requisição GET
	var url = BASE_URL + id_texto
	http_request.request(url)

func _on_http_request_completed(result, response_code, headers, body):
	# DESAFIO BÔNUS: Reabilitar o botão após o fim da requisição
	btn_buscar.disabled = false
	
	# Verificando se a requisição foi bem sucedida (200 OK)
	if response_code == 200:
		var json_string = body.get_string_from_utf8()
		print("RESPOSTA DA API:\n", json_string)
		var data = JSON.parse_string(json_string)
		
		if data != null:
			_preencher_dados(data)
			label_status.text = "Personagem encontrado!"
		else:
			label_status.text = "Erro ao processar o JSON."
			
	# DESAFIO BÔNUS: Mensagem de erro amigável para 404
	elif response_code == 404:
		label_status.text = "Erro 404: Personagem não encontrado no mundo ninja!"
	else:
		label_status.text = "Erro na requisição. Código: " + str(response_code)

func _preencher_dados(data: Dictionary):
	# Usando o método 'get' do Dictionary para evitar erros caso a chave não exista
	label_id.text = "ID: " + str(data.get("id", "N/A"))
	label_nome.text = "Nome: " + data.get("name", "Desconhecido")
	
	# Acessando o objeto "family" com segurança
	var family = data.get("family", {})
	label_pai.text = "Pai: " + family.get("father", "Desconhecido")
	label_mae.text = "Mãe: " + family.get("mother", "Desconhecido")
	
	# Populando a lista de jutsus
	var jutsus = data.get("jutsu", [])
	
	if jutsus.is_empty():
		var lbl = Label.new()
		lbl.text = "Nenhum jutsu registrado."
		scroll_vbox.add_child(lbl)
	else:
		for jutsu in jutsus:
			var lbl = Label.new()
			lbl.text = "• " + jutsu
			scroll_vbox.add_child(lbl)

func _limpar_interface():
	# Reseta os textos
	label_id.text = "ID do Personagem: "
	label_nome.text = "Nome: "
	label_pai.text = "Pai: "
	label_mae.text = "Mãe: "
	
	# Remove os labels antigos de jutsu usando a dica do exercício
	for child in scroll_vbox.get_children():
		child.queue_free()
