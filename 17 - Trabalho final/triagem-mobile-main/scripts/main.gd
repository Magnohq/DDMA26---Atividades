extends Node2D

const BACKEND_BASE_URL: String = "https://backendfalaidoutor.vercel.app/api"
const BACKEND_TRIAGES_ENDPOINT: String = BACKEND_BASE_URL + "/triages"
const BACKEND_PATIENT_TRIAGES_ENDPOINT: String = BACKEND_TRIAGES_ENDPOINT + "/me"
const BACKEND_PENDING_REVIEW_ENDPOINT: String = BACKEND_TRIAGES_ENDPOINT + "/pending-review"
const APPLICATION_KEY: String = "falaidoutor-local-application-key"
const PATIENT_TEXTURE: Texture2D = preload("res://assets/patient_spritesheet.png")
const PROFESSIONAL_TEXTURE: Texture2D = preload("res://assets/professional_spritesheet.png")
const OBJECTIVE_MARKER_SCENE: PackedScene = preload("res://scenes/ObjectiveMarker.tscn")
const PATIENT_TOTEM_MARKER_POSITION: Vector2 = Vector2(724, 126)
const PATIENT_TOTEM_INTERACTION_POINT: Vector2 = Vector2(724, 264)
const PROFESSIONAL_COMPUTER_MARKER_POSITION: Vector2 = Vector2(584, 170)
const PROFESSIONAL_COMPUTER_INTERACTION_POINT: Vector2 = Vector2(584, 260)

@onready var patient = $Patient
@onready var professional = $Professional
@onready var camera = $Camera2D
@onready var http_request = $HTTPRequest
@onready var role_label = $HUD/Root/TopBar/TopInfo/RoleLabel
@onready var hint_label = $HUD/Root/TopBar/TopInfo/HintLabel
@onready var status_label = $HUD/Root/StatusPanel/StatusLabel
@onready var symptom_panel = $HUD/Root/SymptomPanel
@onready var cpf_input = $HUD/Root/SymptomPanel/SymptomBox/CpfInput
@onready var symptom_text = $HUD/Root/SymptomPanel/SymptomBox/SymptomText
@onready var symptom_buttons = $HUD/Root/SymptomPanel/SymptomBox/SymptomButtons
@onready var patient_history_text = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryText
@onready var patient_history_actions = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions
@onready var patient_previous_button = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientPreviousButton
@onready var patient_next_button = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientNextButton
@onready var patient_detail_button = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientDetailButton
@onready var patient_history_close_button = $HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientHistoryCloseButton
@onready var review_panel = $HUD/Root/ReviewPanel
@onready var review_text = $HUD/Root/ReviewPanel/ReviewBox/ReviewText
@onready var confirm_button = $HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ConfirmButton
@onready var review_previous_button = $HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ReviewPreviousButton
@onready var review_next_button = $HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ReviewNextButton
@onready var details_button = $HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/DetailsButton

var active_player: CharacterBody2D
var current_request: String = ""
var patient_tab: String = "new"
var review_tab: String = "pending"
var pending_triage: Dictionary = {}
var pending_review_triages: Array = []
var patient_triages: Array = []
var selected_patient_triage: Dictionary = {}
var selected_patient_triage_index: int = 0
var patient_history_detail_open: bool = false
var should_refresh_patient_history: bool = false
var patient_history_refresh_wait: float = 0.0
var patient_history_request_cpf: String = ""
var analyzed_triages: Array = []
var selected_analyzed_triage: Dictionary = {}
var selected_analyzed_triage_index: int = 0
var confirmed_message: String = ""
var touch_buttons: Dictionary = {}
var patient_objective_marker: Node2D
var professional_objective_marker: Node2D


func _ready() -> void:
	patient.configure("Paciente", "patient", Color(0.24, 0.46, 0.93, 1))
	professional.configure("Enfermeiro", "professional", Color(0.20, 0.58, 0.42, 1))
	patient.set_sprite_texture(PATIENT_TEXTURE)
	professional.set_sprite_texture(PROFESSIONAL_TEXTURE)
	_create_objective_markers()
	_set_active_player(patient)
	_connect_buttons()

	if not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)

	status_label.text = "Paciente: vá ao totem da recepção e pressione Interagir."


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_context_hint()
	_update_patient_history_refresh(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_ui_panel_open():
		return

	if event.is_action_pressed("switch_player"):
		_toggle_player()

	if event.is_action_pressed("interact"):
		_interact()


func _is_ui_panel_open() -> bool:
	return symptom_panel.visible or review_panel.visible


func _set_players_movement_locked(value: bool) -> void:
	patient.set_movement_locked(value)
	professional.set_movement_locked(value)


func _set_active_player(player: CharacterBody2D) -> void:
	active_player = player
	patient.set_active(player == patient)
	professional.set_active(player == professional)
	role_label.text = "Jogador: " + active_player.player_name
	camera.global_position = active_player.global_position
	_update_objective_markers()


func _toggle_player() -> void:
	_close_panels()
	if active_player == patient:
		_set_active_player(professional)
		status_label.text = "Enfermeiro: vá ao computador da recepção para analisar triagens."
	else:
		_set_active_player(patient)
		status_label.text = "Paciente: vá ao totem da recepção para registrar sintomas."


func _update_objective_markers() -> void:
	if patient_objective_marker == null or professional_objective_marker == null:
		return
	patient_objective_marker.visible = active_player == patient
	professional_objective_marker.visible = active_player == professional


func _create_objective_markers() -> void:
	patient_objective_marker = OBJECTIVE_MARKER_SCENE.instantiate()
	patient_objective_marker.name = "PatientObjectiveMarker"
	patient_objective_marker.position = PATIENT_TOTEM_MARKER_POSITION
	add_child(patient_objective_marker)

	professional_objective_marker = OBJECTIVE_MARKER_SCENE.instantiate()
	professional_objective_marker.name = "ProfessionalObjectiveMarker"
	professional_objective_marker.position = PROFESSIONAL_COMPUTER_MARKER_POSITION
	add_child(professional_objective_marker)


func _interact() -> void:
	var station: String = _near_station()

	if active_player.role == "patient" and station == "kiosk":
		_open_symptom_panel()
		return

	if active_player.role == "professional" and station == "computer":
		_open_review_panel()
		return

	if active_player.role == "patient":
		status_label.text = "Paciente precisa estar perto do totem para inserir sintomas."
	else:
		status_label.text = "Enfermeiro precisa estar perto do computador da recepção."


func _near_station() -> String:
	var p: Vector2 = active_player.global_position
	if p.distance_to(PATIENT_TOTEM_INTERACTION_POINT) < 110:
		return "kiosk"
	if p.distance_to(PROFESSIONAL_COMPUTER_INTERACTION_POINT) < 100:
		return "computer"
	return ""


func _open_symptom_panel() -> void:
	review_panel.visible = false
	symptom_panel.visible = true
	_set_players_movement_locked(true)
	_show_patient_new_triage()
	status_label.text = "Totem ativo: envie o CPF e os sintomas para o backend NestJS."


func _open_review_panel() -> void:
	symptom_panel.visible = false
	review_panel.visible = true
	_set_players_movement_locked(true)
	_show_review_pending()


func _close_panels() -> void:
	symptom_panel.visible = false
	review_panel.visible = false
	_set_players_movement_locked(false)


func _show_patient_new_triage() -> void:
	patient_tab = "new"
	symptom_text.visible = true
	symptom_buttons.visible = true
	patient_history_text.visible = false
	patient_history_actions.visible = false
	patient_history_detail_open = false
	symptom_text.grab_focus()
	status_label.text = "Paciente: preencha sintomas para criar nova triagem."


func _show_patient_history() -> void:
	patient_tab = "history"
	symptom_text.visible = false
	symptom_buttons.visible = false
	patient_history_text.visible = true
	patient_history_actions.visible = true
	patient_detail_button.visible = true
	patient_detail_button.disabled = true
	patient_history_close_button.text = "Fechar"
	patient_history_detail_open = false
	patient_history_text.text = "[center]Carregando suas triagens...[/center]"
	_fetch_patient_history()


func _show_review_pending() -> void:
	review_tab = "pending"
	confirm_button.visible = true
	confirm_button.disabled = true
	review_previous_button.visible = false
	review_previous_button.disabled = true
	review_next_button.visible = false
	review_next_button.disabled = true
	details_button.visible = false
	details_button.disabled = true
	review_text.text = "[center]Carregando triagens aguardando revisão...[/center]"
	status_label.text = "Buscando triagens aguardando revisão no backend..."
	_fetch_pending_review()


func _show_review_analyzed() -> void:
	review_tab = "analyzed"
	confirm_button.visible = false
	confirm_button.disabled = true
	review_previous_button.visible = true
	review_previous_button.disabled = true
	review_next_button.visible = true
	review_next_button.disabled = true
	details_button.visible = true
	details_button.disabled = true
	selected_analyzed_triage_index = 0
	selected_analyzed_triage = {}
	review_text.text = "[center]Carregando triagens analisadas...[/center]"
	status_label.text = "Buscando triagens analisadas no backend..."
	_fetch_analyzed_triages()


func _send_symptoms() -> void:
	var cpf: String = _only_digits(cpf_input.text)
	var symptoms: String = symptom_text.text.strip_edges()

	if cpf == "":
		status_label.text = "Informe o CPF do paciente antes de enviar."
		return

	if symptoms == "":
		status_label.text = "Informe os sintomas antes de enviar."
		return

	var payload: Dictionary = {
		"cpf": cpf,
		"symptoms": symptoms
	}

	current_request = "create_triage"
	status_label.text = "Enviando triagem para o backend..."
	var error: Error = _request_json(BACKEND_TRIAGES_ENDPOINT, HTTPClient.METHOD_POST, payload)
	if error != OK:
		status_label.text = "Erro ao iniciar envio da triagem."


func _fetch_patient_history() -> void:
	var cpf: String = _only_digits(cpf_input.text)
	_reset_patient_history_selection()
	if cpf == "":
		patient_history_text.text = "[center]Informe o CPF para consultar suas triagens.[/center]"
		status_label.text = "Informe o CPF antes de consultar o histórico."
		return

	current_request = "fetch_patient_history"
	patient_history_request_cpf = cpf
	patient_history_text.text = "[center]Consultando triagens para o CPF " + cpf + "...[/center]"
	status_label.text = "Consultando histórico do CPF " + cpf + "..."
	var url: String = BACKEND_PATIENT_TRIAGES_ENDPOINT + "?cpf=" + cpf
	var error: Error = http_request.request(url, _default_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		patient_history_text.text = "[center]Erro ao iniciar consulta do histórico.[/center]"
		status_label.text = "Erro ao consultar histórico do paciente."


func _open_selected_patient_details() -> void:
	if selected_patient_triage.is_empty():
		status_label.text = "Selecione uma triagem para detalhar."
		return

	if not _can_patient_open_triage_details(selected_patient_triage):
		status_label.text = "A triagem ainda precisa ser confirmada pelo enfermeiro."
		return

	var triage_id = selected_patient_triage.get("id")
	if triage_id == null:
		status_label.text = "Triagem sem ID para consulta de detalhes."
		return

	current_request = "fetch_patient_triage_details"
	patient_detail_button.disabled = true
	patient_history_text.text = "[center]Carregando detalhes da triagem...[/center]"
	status_label.text = "Buscando detalhes da triagem do paciente..."
	var url: String = BACKEND_TRIAGES_ENDPOINT + "/patient/" + str(int(triage_id))
	var error: Error = http_request.request(url, _default_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		patient_detail_button.disabled = false
		patient_history_text.text = "[center]Erro ao iniciar consulta dos detalhes.[/center]"
		status_label.text = "Erro ao consultar detalhes da triagem."


func _close_patient_history_view() -> void:
	if patient_history_detail_open:
		_render_patient_history()
		status_label.text = "Histórico do paciente carregado."
		return
	_close_panels()



func _select_previous_patient_triage() -> void:
	_select_patient_triage(selected_patient_triage_index - 1)


func _select_next_patient_triage() -> void:
	_select_patient_triage(selected_patient_triage_index + 1)


func _select_patient_triage(index: int) -> void:
	if patient_triages.is_empty():
		return
	selected_patient_triage_index = clamp(index, 0, patient_triages.size() - 1)
	_render_patient_history()



func _on_cpf_input_changed(_new_text: String) -> void:
	if patient_tab != "history" or not symptom_panel.visible:
		return
	patient_history_detail_open = false
	_schedule_patient_history_refresh()


func _schedule_patient_history_refresh() -> void:
	should_refresh_patient_history = true
	patient_history_refresh_wait = 0.6
	_reset_patient_history_selection()
	var cpf: String = _only_digits(cpf_input.text)
	if cpf == "":
		patient_history_text.text = "[center]Informe o CPF para consultar suas triagens.[/center]"
		status_label.text = "Informe o CPF antes de consultar o histórico."
		should_refresh_patient_history = false
		return
	patient_history_text.text = "[center]Consultando triagens para o CPF " + cpf + "...[/center]"
	status_label.text = "CPF alterado. Atualizando histórico..."


func _update_patient_history_refresh(delta: float) -> void:
	if not should_refresh_patient_history:
		return
	patient_history_refresh_wait -= delta
	if patient_history_refresh_wait > 0.0:
		return
	should_refresh_patient_history = false
	_fetch_patient_history()


func _reset_patient_history_selection() -> void:
	patient_triages = []
	selected_patient_triage = {}
	selected_patient_triage_index = 0
	if patient_history_actions != null:
		patient_previous_button.disabled = true
		patient_next_button.disabled = true
		patient_detail_button.disabled = true


func _fetch_pending_review() -> void:
	current_request = "fetch_pending_review"
	var error: Error = http_request.request(BACKEND_PENDING_REVIEW_ENDPOINT, _default_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		review_text.text = "[center]Erro ao iniciar consulta de triagens.[/center]"
		status_label.text = "Erro ao consultar triagens em andamento."


func _fetch_analyzed_triages() -> void:
	current_request = "fetch_analyzed_triages"
	var error: Error = http_request.request(BACKEND_TRIAGES_ENDPOINT, _default_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		review_text.text = "[center]Erro ao iniciar consulta de triagens analisadas.[/center]"
		status_label.text = "Erro ao consultar triagens analisadas."


func _open_selected_analyzed_details() -> void:
	if selected_analyzed_triage.is_empty():
		status_label.text = "Selecione uma triagem analisada para ver detalhes."
		return

	var url: String = _details_url_for_triage(selected_analyzed_triage)
	if url == "":
		status_label.text = "Triagem analisada sem ID para consulta de detalhes."
		return

	current_request = "fetch_triage_details"
	details_button.disabled = true
	review_text.text = "[center]Carregando detalhes da triagem...[/center]"
	status_label.text = "Buscando detalhes da triagem no backend..."
	var error: Error = http_request.request(url, _default_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		details_button.disabled = false
		review_text.text = "[center]Erro ao iniciar consulta dos detalhes.[/center]"
		status_label.text = "Erro ao consultar detalhes da triagem."


func _select_previous_analyzed_triage() -> void:
	_select_analyzed_triage(selected_analyzed_triage_index - 1)


func _select_next_analyzed_triage() -> void:
	_select_analyzed_triage(selected_analyzed_triage_index + 1)


func _select_analyzed_triage(index: int) -> void:
	var selectable_triages: Array = _selectable_analyzed_triages()
	if selectable_triages.is_empty():
		return
	selected_analyzed_triage_index = clamp(index, 0, selectable_triages.size() - 1)
	_render_analyzed_triages()
	status_label.text = "Triagem analisada selecionada."


func _confirm_triage() -> void:
	if pending_triage.is_empty():
		status_label.text = "Não há triagem pendente para confirmar."
		return

	var triage_id = pending_triage.get("id")
	if triage_id == null:
		status_label.text = "Triagem sem ID retornado pelo backend."
		return

	var triage_id_text: String = str(int(triage_id))
	var final_risk: String = str(pending_triage.get("aiSuggestedRiskClassification", ""))
	if final_risk == "":
		final_risk = "ESI-3"

	var payload: Dictionary = {
		"professionalId": "1",
		"professionalNotes": "Triagem revisada pelo enfermeiro no demo Godot.",
		"finalRiskClassification": final_risk,
		"finalRiskColor": str(pending_triage.get("aiSuggestedRiskColor", "yellow"))
	}

	current_request = "confirm_review"
	status_label.text = "Confirmando revisão profissional no backend..."
	var url: String = BACKEND_TRIAGES_ENDPOINT + "/" + triage_id_text + "/professional-review"
	var error: Error = _request_json(url, HTTPClient.METHOD_PATCH, payload)
	if error != OK:
		status_label.text = "Erro ao iniciar confirmação da triagem."


func _request_json(url: String, method: int, payload: Dictionary) -> Error:
	var body_text: String = JSON.stringify(payload)
	return http_request.request(url, _default_headers(), method, body_text)


func _default_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"x-application-key: " + APPLICATION_KEY
	])


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text: String = body.get_string_from_utf8()
	var data = JSON.parse_string(response_text)
	if data == null:
		data = {"raw": response_text}

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_http_error(response_code, data)
		return

	if current_request == "create_triage":
		_handle_create_triage_success(data)
	elif current_request == "fetch_patient_history":
		_handle_patient_history_success(data)
	elif current_request == "fetch_patient_triage_details":
		_handle_patient_triage_details_success(data)
	elif current_request == "fetch_pending_review":
		_handle_pending_review_success(data)
	elif current_request == "fetch_analyzed_triages":
		_handle_analyzed_triages_success(data)
	elif current_request == "fetch_triage_details":
		_handle_triage_details_success(data)
	elif current_request == "confirm_review":
		_handle_confirm_review_success(data)


func _handle_http_error(response_code: int, data) -> void:
	var message: String = _describe_response_error(data)
	if current_request == "fetch_patient_history":
		_reset_patient_history_selection()
		patient_history_text.text = "[center]Erro ao consultar histórico. HTTP " + str(response_code) + "[/center]"
	elif current_request == "fetch_patient_triage_details":
		patient_detail_button.disabled = false
		patient_history_text.text = "[center]Erro ao consultar detalhes. HTTP " + str(response_code) + "[/center]"
	elif current_request == "fetch_pending_review":
		review_text.text = "[center]Erro ao consultar triagens. HTTP " + str(response_code) + "[/center]"
		confirm_button.disabled = true
	elif current_request == "fetch_analyzed_triages":
		review_text.text = "[center]Erro ao consultar triagens analisadas. HTTP " + str(response_code) + "[/center]"
		review_previous_button.disabled = true
		review_next_button.disabled = true
		details_button.disabled = true
	elif current_request == "fetch_triage_details":
		details_button.disabled = false
		review_text.text = "[center]Erro ao consultar detalhes. HTTP " + str(response_code) + "[/center]"
	elif current_request == "create_triage":
		symptom_panel.visible = true
	elif current_request == "confirm_review":
		confirm_button.disabled = false
	status_label.text = "Erro HTTP " + str(response_code) + ": " + message


func _handle_create_triage_success(data) -> void:
	status_label.text = "Triagem enviada. Aguarde o processamento da IA e a revisão do enfermeiro."
	if typeof(data) == TYPE_DICTIONARY:
		pending_triage = data
		confirmed_message = ""
	_show_patient_history()


func _handle_patient_history_success(data) -> void:
	if _only_digits(cpf_input.text) != patient_history_request_cpf:
		_schedule_patient_history_refresh()
		return

	if typeof(data) != TYPE_ARRAY:
		patient_history_text.text = "[center]Resposta inesperada ao consultar suas triagens.[/center]"
		return

	patient_triages = data
	selected_patient_triage_index = 0
	_render_patient_history()
	status_label.text = "Histórico do paciente carregado."


func _handle_patient_triage_details_success(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		patient_history_text.text = "[center]Resposta inesperada ao consultar detalhes da triagem.[/center]"
		patient_detail_button.disabled = false
		return

	_render_patient_triage_details(data)
	status_label.text = "Detalhes da triagem carregados."


func _handle_pending_review_success(data) -> void:
	if typeof(data) != TYPE_ARRAY:
		review_text.text = "[center]Resposta inesperada ao consultar triagens.[/center]"
		confirm_button.disabled = true
		return

	pending_review_triages = data
	if pending_review_triages.is_empty():
		pending_triage = {}
		review_text.text = "[center]Nenhuma triagem aguardando revisão profissional.[/center]"
		confirm_button.disabled = true
		status_label.text = "Nenhuma triagem em andamento para revisar."
		return

	pending_triage = pending_review_triages[0]
	confirmed_message = ""
	_render_review()
	status_label.text = "Triagem carregada para revisão do enfermeiro."


func _handle_analyzed_triages_success(data) -> void:
	if typeof(data) != TYPE_ARRAY:
		review_text.text = "[center]Resposta inesperada ao consultar triagens analisadas.[/center]"
		return

	analyzed_triages = data
	selected_analyzed_triage_index = 0
	_render_analyzed_triages()
	status_label.text = "Triagens analisadas carregadas."


func _handle_triage_details_success(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		review_text.text = "[center]Resposta inesperada ao consultar detalhes da triagem.[/center]"
		details_button.disabled = false
		return

	_render_triage_details(data)
	details_button.disabled = false
	status_label.text = "Detalhes da triagem carregados."


func _handle_confirm_review_success(data) -> void:
	confirmed_message = "Triagem confirmada pelo enfermeiro."
	if typeof(data) == TYPE_DICTIONARY:
		confirmed_message = "Triagem " + str(data.get("id", "")) + " confirmada pelo enfermeiro."
	status_label.text = confirmed_message
	_render_review()


func _describe_response_error(data) -> String:
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("message"):
			return str(data.get("message"))
		if data.has("error"):
			return str(data.get("error"))
		if data.has("raw"):
			return str(data.get("raw"))
	return "Falha na requisição."


func _render_patient_history() -> void:
	patient_history_detail_open = false
	patient_history_actions.visible = true
	patient_previous_button.visible = true
	patient_next_button.visible = true
	patient_detail_button.visible = true
	patient_history_close_button.text = "Fechar"
	selected_patient_triage = {}

	if patient_triages.is_empty():
		selected_patient_triage_index = 0
		patient_previous_button.disabled = true
		patient_next_button.disabled = true
		patient_detail_button.disabled = true
		patient_history_text.text = "[center]Nenhuma triagem encontrada para este CPF.[/center]"
		return

	selected_patient_triage_index = clamp(selected_patient_triage_index, 0, patient_triages.size() - 1)
	patient_previous_button.disabled = selected_patient_triage_index <= 0
	patient_next_button.disabled = selected_patient_triage_index >= patient_triages.size() - 1
	patient_detail_button.disabled = true

	var lines: Array[String] = []
	for index in range(patient_triages.size()):
		var triage = patient_triages[index]
		if typeof(triage) != TYPE_DICTIONARY:
			continue
		if index == selected_patient_triage_index:
			selected_patient_triage = triage
			patient_detail_button.disabled = not _can_patient_open_triage_details(triage)
		var ticket: String = str(triage.get("queueTicket", "-"))
		var date_text: String = _short_date(str(triage.get("createdAt", "")))
		var patient_status: String = str(triage.get("patientStatus", triage.get("status", "-")))
		var risk: String = str(triage.get("riskClassification", "Aguardando IA"))
		if risk == "" or risk == "<null>":
			risk = "Aguardando IA"
		var symptoms: String = _triage_symptoms_text(triage)
		var marker: String = "[color=yellow]Selecionada[/color]\n" if index == selected_patient_triage_index else ""
		lines.append(marker + "[b]" + ticket + "[/b]  " + patient_status + "  " + risk + "\n" + date_text + " - " + symptoms)
	var cpf: String = _only_digits(cpf_input.text)
	patient_history_text.text = "[b]CPF:[/b] " + cpf + "\n\n" + "\n\n".join(lines)


func _render_patient_triage_details(details: Dictionary) -> void:
	patient_history_detail_open = true
	patient_history_actions.visible = true
	patient_previous_button.visible = false
	patient_next_button.visible = false
	patient_detail_button.visible = false
	patient_history_close_button.text = "Fechar"
	var criteria_text: String = _join_array_values(details.get("criterios_ponto_decisao", []))
	var classification: String = _format_esi_classification(str(details.get("classificacao", details.get("finalRiskClassification", "-"))))
	patient_history_text.text = "[b]Senha:[/b] %s\n[b]Data:[/b] %s %s\n[b]Sintomas:[/b] %s\n[b]Classificação:[/b] %s - %s\n[b]Ponto de decisão:[/b] %s\n[b]Critérios:[/b] %s\n[b]Ação recomendada:[/b] %s\n\n[b]Justificativa:[/b]\n%s" % [
		details.get("queueTicket", "-"),
		details.get("createdAtDate", "-"),
		details.get("createdAtTime", ""),
		details.get("symptoms", "-"),
		details.get("classificacao", details.get("finalRiskClassification", "-")),
		details.get("nome_nivel", "-"),
		details.get("ponto_decisao_ativado", "-"),
		criteria_text,
		details.get("aiRecommendedAction", "-"),
		details.get("justificativa", details.get("aiSummary", "-"))
	]
	patient_history_text.text = "[b]Senha:[/b] %s\n[b]Data:[/b] %s %s\n[b]Sintomas:[/b] %s\n[b]Classificacao:[/b] %s\n[b]Ponto de decisao:[/b] %s\n[b]Criterios:[/b] %s\n[b]Acao recomendada:[/b] %s\n\n[b]Justificativa:[/b]\n%s" % [
		details.get("queueTicket", "-"),
		details.get("createdAtDate", "-"),
		details.get("createdAtTime", ""),
		details.get("symptoms", "-"),
		classification,
		details.get("ponto_decisao_ativado", "-"),
		criteria_text,
		details.get("aiRecommendedAction", "-"),
		details.get("justificativa", details.get("aiSummary", "-"))
	]


func _render_review() -> void:
	if pending_triage.is_empty():
		review_text.text = "[center]Nenhuma triagem pendente.[/center]"
		confirm_button.disabled = true
		return

	var raw_summary: String = str(pending_triage.get("aiSummary", pending_triage.get("summary", "Aguardando resumo da IA.")))
	var suggested_risk: String = str(pending_triage.get("aiSuggestedRiskClassification", "-"))
	var recommended_action: String = str(pending_triage.get("aiRecommendedAction", "-"))
	review_text.text = "[b]Paciente:[/b] %s\n[b]CPF/ID:[/b] %s\n[b]Sintomas:[/b] %s\n[b]Risco sugerido:[/b] %s\n[b]Ação recomendada:[/b] %s\n\n[b]Resumo IA:[/b]\n%s" % [
		pending_triage.get("patientName", "Paciente"),
		str(pending_triage.get("patientId", "-")),
		pending_triage.get("symptoms", "-"),
		suggested_risk,
		recommended_action,
		raw_summary
	]
	if confirmed_message != "":
		review_text.text += "\n\n[color=green][b]Paciente notificado:[/b] " + confirmed_message + "[/color]"
	confirm_button.disabled = confirmed_message != ""


func _render_analyzed_triages() -> void:
	var lines: Array[String] = []
	var selectable_triages: Array = _selectable_analyzed_triages()
	selected_analyzed_triage = {}
	selected_analyzed_triage_index = clamp(selected_analyzed_triage_index, 0, max(selectable_triages.size() - 1, 0))
	review_previous_button.disabled = true
	review_next_button.disabled = true
	details_button.disabled = true

	if selectable_triages.is_empty():
		review_text.text = "[center]Nenhuma triagem analisada na fila atual.[/center]"
		return

	review_previous_button.disabled = selected_analyzed_triage_index <= 0
	review_next_button.disabled = selected_analyzed_triage_index >= selectable_triages.size() - 1
	details_button.disabled = false

	for index in range(selectable_triages.size()):
		var triage = selectable_triages[index]
		if index == selected_analyzed_triage_index:
			selected_analyzed_triage = triage
		var status: String = str(triage.get("status", ""))
		var risk: String = _format_esi_classification(str(triage.get("classificacao", triage.get("riskClassification", triage.get("finalRiskClassification", "-")))))
		var name: String = str(triage.get("name", triage.get("patientName", "Paciente")))
		var ticket: String = str(triage.get("queueTicket", "-"))
		var symptoms: String = _triage_symptoms_text(triage)
		var source: String = str(triage.get("source", "triage"))
		var marker: String = "[color=yellow]Selecionada[/color]\n" if index == selected_analyzed_triage_index else ""
		lines.append(marker + "[b]" + ticket + "[/b]  " + name + "\n" + symptoms + "\n" + risk + "  [color=gray]" + source + "[/color]")

	review_text.text = "\n\n".join(lines)


func _selectable_analyzed_triages() -> Array:
	var selectable_triages: Array = []
	for triage in analyzed_triages:
		if typeof(triage) != TYPE_DICTIONARY:
			continue
		var status: String = str(triage.get("status", ""))
		var risk: String = str(triage.get("classificacao", triage.get("riskClassification", triage.get("finalRiskClassification", "-"))))
		if status == "WAITING_PROFESSIONAL_REVIEW" or risk == "" or risk == "-":
			continue
		selectable_triages.append(triage)
	return selectable_triages


func _can_patient_open_triage_details(triage: Dictionary) -> bool:
	var status: String = str(triage.get("status", "")).to_upper()
	var patient_status: String = str(triage.get("patientStatus", "")).to_upper()
	var risk: String = str(triage.get("riskClassification", triage.get("classificacao", triage.get("finalRiskClassification", triage.get("aiSuggestedRiskClassification", ""))))).strip_edges()
	var risk_upper: String = risk.to_upper()

	if status == "WAITING_PROFESSIONAL_REVIEW" or status == "PENDING_REVIEW":
		return false
	if status.contains("PENDING") or status.contains("PROCESSING"):
		return false
	if patient_status.contains("AGUARD"):
		return false
	if patient_status.contains("EM_ANALISE") or patient_status.contains("EM ANALISE"):
		return false
	if risk == "" or risk == "<null>" or risk_upper.contains("AGUARD"):
		return false

	return true


func _triage_symptoms_text(triage: Dictionary) -> String:
	var keys: Array[String] = [
		"symptomsPreview",
		"symptoms",
		"sintomas",
		"complaint",
		"chiefComplaint",
		"symptomDescription",
		"symptomsText",
		"patientSymptoms",
		"description",
		"descricao",
		"descricaoSintomas",
		"queixa",
		"queixaPrincipal"
	]
	for key in keys:
		var value = triage.get(key)
		if value != null:
			var text: String = str(value).strip_edges()
			if text != "" and text != "<null>" and text != "-":
				return text
	var nested_keys: Array[String] = ["patientTriage", "triage", "queueTriage"]
	for nested_key in nested_keys:
		var nested = triage.get(nested_key)
		if typeof(nested) == TYPE_DICTIONARY:
			var nested_text: String = _triage_symptoms_text(nested)
			if nested_text != "-":
				return nested_text
	return "-"


func _format_esi_classification(value: String) -> String:
	var digits: String = _only_digits(value)
	if digits != "":
		return "ESI " + digits.substr(0, 1)
	return value.replace("-", " ").strip_edges()


func _render_triage_details(details: Dictionary) -> void:
	var criteria_text: String = _join_array_values(details.get("criterios_ponto_decisao", []))
	var classification: String = _format_esi_classification(str(details.get("classificacao", details.get("finalRiskClassification", "-"))))
	review_text.text = "[b]Paciente:[/b] %s\n[b]Senha:[/b] %s\n[b]Idade/Sexo:[/b] %s anos / %s\n[b]Sintomas:[/b] %s\n[b]Classificação:[/b] %s - %s\n[b]Ponto de decisão:[/b] %s\n[b]Critérios:[/b] %s\n[b]Ação recomendada:[/b] %s\n\n[b]Justificativa:[/b]\n%s\n\n[b]Observações profissionais:[/b]\n%s" % [
		details.get("name", "Paciente"),
		details.get("queueTicket", "-"),
		str(details.get("age", "-")),
		details.get("gender", "-"),
		details.get("symptoms", "-"),
		details.get("classificacao", details.get("finalRiskClassification", "-")),
		details.get("nome_nivel", "-"),
		details.get("ponto_decisao_ativado", "-"),
		criteria_text,
		details.get("aiRecommendedAction", "-"),
		details.get("justificativa", details.get("aiSummary", "-")),
		details.get("professionalNotes", "-")
	]
	review_text.text = "[b]Paciente:[/b] %s\n[b]Senha:[/b] %s\n[b]Idade/Sexo:[/b] %s anos / %s\n[b]Sintomas:[/b] %s\n[b]Classificacao:[/b] %s\n[b]Ponto de decisao:[/b] %s\n[b]Criterios:[/b] %s\n[b]Acao recomendada:[/b] %s\n\n[b]Justificativa:[/b]\n%s\n\n[b]Observacoes profissionais:[/b]\n%s" % [
		details.get("name", "Paciente"),
		details.get("queueTicket", "-"),
		str(details.get("age", "-")),
		details.get("gender", "-"),
		details.get("symptoms", "-"),
		classification,
		details.get("ponto_decisao_ativado", "-"),
		criteria_text,
		details.get("aiRecommendedAction", "-"),
		details.get("justificativa", details.get("aiSummary", "-")),
		details.get("professionalNotes", "-")
	]


func _connect_buttons() -> void:
	$HUD/Root/SymptomPanel/SymptomBox/PatientTabs/NewTriageButton.pressed.connect(_show_patient_new_triage)
	$HUD/Root/SymptomPanel/SymptomBox/PatientTabs/PatientHistoryButton.pressed.connect(_show_patient_history)
	$HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientPreviousButton.pressed.connect(_select_previous_patient_triage)
	$HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientNextButton.pressed.connect(_select_next_patient_triage)
	$HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientDetailButton.pressed.connect(_open_selected_patient_details)
	$HUD/Root/SymptomPanel/SymptomBox/PatientHistoryActions/PatientHistoryCloseButton.pressed.connect(_close_patient_history_view)
	cpf_input.text_changed.connect(_on_cpf_input_changed)
	$HUD/Root/SymptomPanel/SymptomBox/SymptomButtons/SendSymptomsButton.pressed.connect(_send_symptoms)
	$HUD/Root/SymptomPanel/SymptomBox/SymptomButtons/CloseSymptomsButton.pressed.connect(_close_panels)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewTabs/PendingReviewButton.pressed.connect(_show_review_pending)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewTabs/AnalyzedReviewButton.pressed.connect(_show_review_analyzed)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ConfirmButton.pressed.connect(_confirm_triage)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ReviewPreviousButton.pressed.connect(_select_previous_analyzed_triage)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/ReviewNextButton.pressed.connect(_select_next_analyzed_triage)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/DetailsButton.pressed.connect(_open_selected_analyzed_details)
	$HUD/Root/ReviewPanel/ReviewBox/ReviewButtons/CloseReviewButton.pressed.connect(_close_panels)
	$HUD/Root/TouchControls/InteractButton.pressed.connect(_interact)
	$HUD/Root/TouchControls/SwitchButton.pressed.connect(_toggle_player)

	touch_buttons = {
		$HUD/Root/TouchControls/UpButton: Vector2.UP,
		$HUD/Root/TouchControls/DownButton: Vector2.DOWN,
		$HUD/Root/TouchControls/LeftButton: Vector2.LEFT,
		$HUD/Root/TouchControls/RightButton: Vector2.RIGHT
	}

	for button in touch_buttons.keys():
		button.button_down.connect(_on_touch_direction_changed)
		button.button_up.connect(_on_touch_direction_changed)


func _on_touch_direction_changed() -> void:
	var vector: Vector2 = Vector2.ZERO
	for button in touch_buttons.keys():
		if button.button_pressed:
			vector += touch_buttons[button]
	active_player.set_touch_vector(vector.normalized() if vector != Vector2.ZERO else Vector2.ZERO)


func _update_camera(delta: float) -> void:
	var target: Vector2 = active_player.global_position
	camera.global_position = camera.global_position.lerp(target, min(delta * 6.0, 1.0))


func _update_context_hint() -> void:
	var station: String = _near_station()
	if active_player.role == "patient" and station == "kiosk":
		hint_label.text = "Interagir: abrir totem de sintomas"
	elif active_player.role == "professional" and station == "computer":
		hint_label.text = "Interagir: abrir computador de triagem"
	else:
		hint_label.text = "WASD/setas movem, E interage, Tab troca personagem"


func _details_url_for_triage(triage: Dictionary) -> String:
	var source: String = str(triage.get("source", "queue-triage"))
	if source == "patient-triage":
		var patient_triage_id = triage.get("triageId", triage.get("queueId"))
		if patient_triage_id == null:
			return ""
		return BACKEND_TRIAGES_ENDPOINT + "/patient/" + str(int(patient_triage_id))

	var queue_id = triage.get("queueId")
	if queue_id == null:
		return ""
	return BACKEND_TRIAGES_ENDPOINT + "/" + str(int(queue_id))


func _join_array_values(value) -> String:
	if typeof(value) != TYPE_ARRAY or value.is_empty():
		return "-"
	var parts: Array[String] = []
	for item in value:
		parts.append(str(item))
	return ", ".join(parts)


func _short_date(value: String) -> String:
	if value.length() >= 10:
		return value.substr(0, 10)
	return "-"


func _only_digits(value: String) -> String:
	var digits: String = ""
	for i in range(value.length()):
		var character: String = value.substr(i, 1)
		if character >= "0" and character <= "9":
			digits += character
	return digits
