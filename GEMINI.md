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
- **交叉通信**：使用全局单例 `EventBus.gd` 或 `GameManager.gd`。

## 3. 文件目录规范
- `res://src/autoload/`: 全局单例 (EventBus, GameManager, etc.)
- `res://src/components/`: 通用组件 (Health, Hitbox, etc.)
- `res://src/entities/`: 具体实体 (Player, Core, Enemies)
- `res://src/ui/`: 界面相关
- `res://scenes/`: 场景文件 (.tscn)
- `res://assets/`: 原始资源 (Textures, Sounds)

## 4. 命名规范
- **类名 (class_name)**：使用 PascalCase。
- **变量/方法**：使用 snake_case。
- **常量**：使用 CONSTANT_CASE。

## 5. 会话恢复说明
每次开始新会话前，必须阅读 `docs/TASKS.md` 以确定当前进度。
完成任务后必须更新 `docs/TASKS.md`。
