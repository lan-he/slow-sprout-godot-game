extends CharacterBody2D

# --- 导出调节参数 ---
@export var speed: float = 120.0
@export var detect_radius: float = 250.0
@export var attack_radius: float = 50.0  # 建议设为 50 左右，防止贴死不触发
@export var return_threshold: float = 15.0

# --- 动画树需要的表达式变量 (必须与 AnimationTree 连线一致) ---
var is_moving: bool = false
var is_attacking: bool = false

# --- AI 逻辑变量 ---
enum State { STAND, CHASE, ATTACK, RETURN }
var current_state = State.STAND
var target: CharacterBody2D = null
var home_position: Vector2

@onready var anim_tree = $AnimationTree
@onready var ray_cast = $RayCast2D

func _ready():
	home_position = global_position
	anim_tree.active = true
	# 确保射线已开启且不撞到敌人自己
	ray_cast.enabled = true
	ray_cast.exclude_parent = true 

func _physics_process(_delta):
	# 每帧重置移动状态，由后面的逻辑决定是否为 true
	is_moving = false
	
	match current_state:
		State.STAND:
			handle_stand_state()
		State.CHASE:
			handle_chase_state()
		State.ATTACK:
			handle_attack_state()
		State.RETURN:
			handle_return_state()

	# 最终移动执行
	if current_state != State.ATTACK:
		move_and_slide()
		is_moving = velocity.length() > 5.0

# --- 状态函数集 ---

func handle_stand_state():
	velocity = Vector2.ZERO
	var p = find_player_in_range()
	if p and can_see_player(p):
		target = p
		current_state = State.CHASE

func handle_chase_state():
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	# 1. 实时更新射线指向玩家 (解决射线不动的问题)
	if not can_see_player(target) or global_position.distance_to(target.global_position) > detect_radius:
		target = null
		current_state = State.RETURN
		return

	# 2. 检查攻击距离
	var dist = global_position.distance_to(target.global_position)
	if dist <= attack_radius:
		velocity = Vector2.ZERO
		is_attacking = true  # 触发 AnimationTree 切换到 AttackState
		current_state = State.ATTACK
		# 攻击时也要面向玩家
		var dir_to_player = (target.global_position - global_position).normalized()
		update_blend_positions(dir_to_player)
		return

	# 3. 追逐移动
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed
	update_blend_positions(dir)

func handle_attack_state():
	velocity = Vector2.ZERO
	# 利用 AnimationTree 的播放进度来切换回追逐
	var playback = anim_tree.get("parameters/playback")
	# 如果动画已经自动切回了 StandState (或 RunState)，说明攻击播完了
	if playback.get_current_node() != "AttackState":
		is_attacking = false
		current_state = State.CHASE

func handle_return_state():
	var dist_to_home = global_position.distance_to(home_position)
	if dist_to_home < return_threshold:
		velocity = Vector2.ZERO
		current_state = State.STAND
		return

	var dir = (home_position - global_position).normalized()
	velocity = dir * speed
	update_blend_positions(dir)
	
	# 返回途中如果再次看到玩家，直接开追
	var p = find_player_in_range()
	if p and can_see_player(p):
		target = p
		current_state = State.CHASE

# --- 工具函数 ---

func can_see_player(p):
	# 关键：每帧将全局坐标转换为本地坐标赋给 target_position
	ray_cast.target_position = to_local(p.global_position)
	# 立即更新物理探测
	ray_cast.force_raycast_update()
	# 如果没有碰撞，说明视线没有被遮挡
	return !ray_cast.is_colliding()

func find_player_in_range():
	# 确保玩家在 "player" 分组
	var p = get_tree().get_first_node_in_group("player")
	if p and global_position.distance_to(p.global_position) < detect_radius:
		return p
	return null

func update_blend_positions(dir: Vector2):
	if dir == Vector2.ZERO: return
	# 这里的路径必须匹配你 AnimationTree 中的节点名称
	anim_tree.set("parameters/StandState/blend_position", dir)
	anim_tree.set("parameters/RunState/blend_position", dir)
	anim_tree.set("parameters/AttackState/blend_position", dir)
