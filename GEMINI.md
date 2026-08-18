# No Ascension Tonight: 架构开发规范

## 1. 核心原则：组合优于继承 (Composition over Inheritance)
严禁建立深层的类继承体系。所有实体（玩家、敌人、物件）必须通过 **Node 组合** 来实现功能。

### 推荐做法
- 实体 (Node2D/CharacterBody2D)
  - Sprite2D (视觉)
  - HealthComponent (数据与生命逻辑)
  - HitboxComponent (攻击区域)
  - HurtboxComponent (受击区域)
  - StateMachine (状态机)

## 2. 信号与解耦
- **向上通知 (Signals)**：组件通过信号通知父节点或全局单例。
- **向下调用 (Functions)**：父节点通过方法调用控制子组件。
- **交叉通信**：使用全局单例 `event_bus.gd` 或 `game_manager.gd`。

## 3. 文件目录规范
- `res://src/autoload/`: 全局单例 (EventBus, GameManager, etc.)
- `res://src/components/`: 通用组件 (Health, Hitbox, etc.)
- `res://src/entities/`: 具体实体 (Player, Core, Enemies)
- `res://src/ui/`: 界面相关
- `res://src/tests/`: 测试场景脚本
- `res://scenes/`: 场景文件 (.tscn)，按 UI、关卡、实体、世界、武器、测试分组
- `res://assets/textures/`: 运行时纹理，按用途分组

## 4. 命名规范
- **类名 (class_name)**：使用 PascalCase。
- **文件名**：使用 snake_case，脚本与场景名称保持对应。
- **变量/方法**：使用 snake_case。
- **常量**：使用 CONSTANT_CASE。

## 5. 会话恢复说明
每次开始新会话前，必须阅读 `docs/TASKS.md` 以确定当前进度。
完成任务后必须更新 `docs/TASKS.md`。
