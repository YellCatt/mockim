# Mockim - Mock RESTful API Server

一个基于 Nim 编写的 Mock RESTful API 服务器，通过读取 PSV（Pipe-Separated Values）配置文件来模拟 RESTful API 接口，方便前端开发调试。

## 特性

- 从 PSV 文件读取 API 配置
- 支持所有 HTTP 方法（GET、POST、PUT、DELETE、PATCH 等）
- 支持路径参数（如 `/api/users/{id}`）
- 可配置响应状态码、Content-Type、响应体
- 支持模拟网络延迟
- 支持自定义响应头
- 内置 CORS 支持，方便前端跨域调用
- 支持通过 YAML 配置文件设置端口和主机
- 零外部依赖，仅使用 Nim 标准库

## 安装

### 前提条件

- 安装 [Nim](https://nim-lang.org/install.html) (>= 1.6.0)

### 编译

```bash
# 克隆项目
cd mockim

# 编译
nimble build

# 或编译为发布版本
nimble build -d:release
```

## 使用方法

```bash
# 自动扫描当前目录下的所有 *.psv 文件并启动服务
./mockim

# 指定目录，自动加载该目录下所有 *.psv 文件
./mockim examples

# 仍然支持指定单个 PSV 文件
./mockim examples/apis.psv

# 指定 YAML 配置文件（默认读取当前目录的 config.yaml）
./mockim --config examples/config.yaml

# 指定端口
./mockim --port 3000

# 指定主机
./mockim --host 127.0.0.1 --port 3000

# 查看帮助
./mockim --help
```

## YAML 配置文件

服务启动时会自动读取当前目录下的 `config.yaml`（也可通过 `--config` 指定）。目前支持以下字段：

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `port` | 服务监听端口 | `8080` |
| `host` | 服务监听主机 | `0.0.0.0` |
| `psv_path` | PSV 文件或目录路径，优先级低于命令行位置参数 | `""` |

### 示例

```yaml
# config.yaml
port: 8080
host: "0.0.0.0"
psv_path: "examples"
```

优先级：`--port` / `--host` 命令行参数 > YAML 配置文件 > 内置默认值。

## PSV 文件格式

PSV 文件使用管道符 `|` 分隔列，第一行为表头。

### 必需列

| 列名 | 说明 |
|------|------|
| `method` | HTTP 方法：GET、POST、PUT、DELETE、PATCH、HEAD、OPTIONS |
| `path` | API 路径，支持路径参数（如 `/api/users/{id}`） |

### 可选列

| 列名 | 说明 | 默认值 |
|------|------|--------|
| `desc` | 接口描述，启动时会显示在日志中 | 空字符串 |
| `status` | HTTP 状态码 | 200 |
| `headers` | 自定义响应头，可包含 Content-Type（默认 application/json），格式：`key1:value1,key2:value2` | 无 |
| `request` | 请求体子串匹配，多条件用 `&&` 分隔，格式：`sub1&&sub2` | 无 |
| `response` | 响应体内容 | 空字符串 |
| `delay_ms` | 模拟延迟（毫秒） | 0 |
| `query` | 查询参数匹配，格式：`key1=value1,key2=value2` | 无 |


### 字段转义

字段内容如需包含管道符 `|`，可用双引号 `"` 包裹整列；输出时会自动去掉外层引号。字段内的双引号需用两个双引号 `""` 转义。

```psv
# request 字段包含 JSON，其中含 |
某接口|POST|/api/test||200||"{""path"":""a|b"",""status"":""ok""}"|{"ok":true}|0
```

### 示例

```psv
desc|method|path|query|status|headers|request|response|delay_ms
获取用户列表|GET|/api/users||200||||[{"id":1,"name":"Alice"}]|0
按状态查用户|GET|/api/users|status=active|200||||[{"id":1}]|0
登录-alice|POST|/api/login||200||"username":"alice"&&"password":"123456"|{"token":"abc-123"}|0
完整JSON入参|POST|/api/orders||201||{"userId":10,"items":[{"productId":1,"qty":2}]}|{"orderId":100}|0
自定义响应头|GET|/api/custom-headers||200|X-Custom-Header:hello|||<root>ok</root>|0
删除用户|DELETE|/api/users/{id}||204|||||0
```

### 注释

以 `#` 开头的行会被视为注释，不会解析。

## 前端调用示例

```javascript
// 获取用户列表
fetch('http://localhost:8080/api/users')
  .then(res => res.json())
  .then(data => console.log(data));

// 获取单个用户
fetch('http://localhost:8080/api/users/1')
  .then(res => res.json())
  .then(data => console.log(data));

// 创建用户
fetch('http://localhost:8080/api/users', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ name: 'Charlie' })
})
.then(res => res.json())
.then(data => console.log(data));
```

## 项目结构

```
mockim/
├── mockim.nimble      # Nim 包配置
├── README.md          # 项目说明
├── config.yaml        # 服务启动配置（端口/主机）
├── src/
│   ├── mockim.nim     # 主程序入口
│   ├── types.nim      # 数据类型定义
│   ├── config.nim     # 配置入口（聚合 PSV / YAML 解析）
│   ├── psv.nim        # PSV 文件解析
│   ├── yaml.nim       # YAML 文件解析
│   └── server.nim     # HTTP 服务器逻辑
└── examples/
    ├── apis.psv       # 示例 PSV 配置文件
    └── config.yaml    # 示例 YAML 配置文件
```

## 许可证

MIT
