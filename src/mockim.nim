import std/[os, strutils]
import config, server

proc printUsage() =
  echo "Mockim - Mock RESTful API Server"
  echo ""
  echo "Usage:"
  echo "  mockim [path] [options]"
  echo ""
  echo "Arguments:"
  echo "  path             PSV file or directory to scan (default: current directory)"
  echo ""
  echo "Options:"
  echo "  --config <file>  YAML config file (default: config.yaml)"
  echo "                   Supported fields: port, host, psv_path"
  echo "  --port <port>    Server port (default: 8080)"
  echo "  --host <host>    Server host (default: 0.0.0.0)"
  echo ""
  echo "PSV File Format:"
  echo "  The PSV file should have pipe-separated columns with a header row."
  echo ""
  echo "Required columns:"
  echo "  method  - HTTP method (GET, POST, PUT, DELETE, PATCH, etc.)"
  echo "  path    - API endpoint path (e.g., /api/users, /api/users/{id})"
  echo ""
  echo "Optional columns:"
  echo "  desc        - API description shown in startup log"
  echo "  status      - HTTP status code (default: 200)"
  echo "  headers     - Additional headers, may include Content-Type (default: application/json)"

  echo "  request     - Request body substrings to match (format: sub1,sub2)"
  echo "  response    - Response body content"
  echo "  delay_ms    - Artificial delay in milliseconds"
  echo "  query       - Query params to match (format: key1=value1,key2=value2)"
  echo ""
  echo "Example PSV file:"
  echo "  desc|method|path|query|status|request|response|delay_ms"
  echo "  获取用户列表|GET|/api/users||200|application/json|[{\"id\":1,\"name\":\"Alice\"}]|0"
  echo "  按状态查用户|GET|/api/users|status:active|200|application/json|[{\"id\":1}]|0"
  echo "  登录|POST|/api/login||200||\"username\":\"alice\"|{\"token\":\"abc\"}|0"
  echo "  删除用户|DELETE|/api/users/{id}||204|||0"

proc findDefaultConfigFile(): string =
  # Current directory takes precedence for backward compatibility
  if fileExists("config.yaml"):
    return "config.yaml"
  # Executable directory (release layout)
  let appDir = getAppDir()
  if fileExists(appDir / "config.yaml"):
    return appDir / "config.yaml"
  # Parent of executable directory (development layout: src/mockim.exe)
  let parentDir = appDir.parentDir
  if fileExists(parentDir / "config.yaml"):
    return parentDir / "config.yaml"
  return "config.yaml"

proc findDefaultPsvPath(): string =
  # Current directory takes precedence
  if discoverPsvFiles(".").len > 0:
    return "."
  # Fall back to examples directory
  if dirExists("examples") and discoverPsvFiles("examples").len > 0:
    return "examples"
  return "."

proc main() =
  let args = commandLineParams()

  if args.len > 0 and args[0] in ["-h", "--help", "help"]:
    printUsage()
    quit(0)

  var psvPath = ""
  var configFile = findDefaultConfigFile()
  var portOverride = -1
  var hostOverride = ""

  var i = 0
  while i < args.len:
    let arg = args[i]
    if arg == "--config":
      if i + 1 < args.len:
        configFile = args[i + 1]
        i += 2
      else:
        echo "Error: --config requires a value"
        quit(1)
    elif arg == "--port":
      if i + 1 < args.len:
        try:
          portOverride = parseInt(args[i + 1])
        except ValueError:
          echo "Error: invalid port: ", args[i + 1]
          quit(1)
        i += 2
      else:
        echo "Error: --port requires a value"
        quit(1)
    elif arg == "--host":
      if i + 1 < args.len:
        hostOverride = args[i + 1]
        i += 2
      else:
        echo "Error: --host requires a value"
        quit(1)
    elif arg.startsWith("--"):
      echo "Warning: Unknown argument: ", arg
      i += 1
    else:
      # First positional argument is the PSV file/directory path
      if psvPath == "":
        psvPath = arg
      else:
        echo "Warning: Extra positional argument ignored: ", arg
      i += 1

  let yamlConfig = parseYamlConfig(configFile)

  if psvPath == "":
    if yamlConfig.found and yamlConfig.psvPath.len > 0:
      psvPath = yamlConfig.psvPath
    else:
      psvPath = findDefaultPsvPath()

  if not (fileExists(psvPath) or dirExists(psvPath)):
    echo "Error: PSV file or directory not found: ", psvPath
    quit(1)

  var mockConfig = parsePsvFromPath(psvPath)

  if yamlConfig.found:
    mockConfig.port = yamlConfig.port
    mockConfig.host = yamlConfig.host

  if portOverride != -1:
    mockConfig.port = portOverride
  if hostOverride.len > 0:
    mockConfig.host = hostOverride

  if fileExists(psvPath):
    echo "Loading PSV file: ", psvPath
  else:
    let files = discoverPsvFiles(psvPath)
    echo "Loading PSV files from: ", psvPath
    for f in files:
      echo "  - ", f
  if yamlConfig.found:
    echo "Loading YAML config: ", configFile
  echo "Found ", mockConfig.endpoints.len, " endpoint(s)"

  startServer(mockConfig)

when isMainModule:
  main()
