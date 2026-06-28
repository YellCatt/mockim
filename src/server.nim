import std/[asyncdispatch, asynchttpserver, tables, strutils, uri]
import types

var globalConfig {.threadvar.}: MockConfig

proc default404Endpoint*(): ApiEndpoint =
  var defaultHeaders = initTable[string, string]()
  defaultHeaders["Content-Type"] = "application/json"
  result = ApiEndpoint(
    methodType: hmGet,
    path: "",
    desc: "",
    statusCode: 404,
    responseBody: "{\"error\": \"Not Found\"}",
    delayMs: 0,
    headers: defaultHeaders,
    queryParams: initTable[string, string](),
    bodySubstrings: @[]
  )

proc findEndpoint(reqMethod: types.HttpMethod, reqPath: string,
                  reqQuery: Table[string, string],
                  reqBodyRaw: string): ApiEndpoint =
  # Step 1: collect candidates by method + path (including path parameters)
  var candidates: seq[ApiEndpoint] = @[]
  for ep in globalConfig.endpoints:
    if ep.methodType != reqMethod:
      continue
    if ep.path == reqPath:
      candidates.add(ep)
      continue

    let epParts = ep.path.split("/")
    let reqParts = reqPath.split("/")

    if epParts.len != reqParts.len:
      continue

    var matched = true
    for i in 0 ..< epParts.len:
      if epParts[i].startsWith("{") and epParts[i].endsWith("}"):
        continue
      if epParts[i] != reqParts[i]:
        matched = false
        break

    if matched:
      candidates.add(ep)

  if candidates.len == 0:
    return default404Endpoint()

  # Step 2: score candidates by matching query params and body substrings
  var bestScore = -1
  var bestIdx = -1
  var fallbackIdx = -1

  for idx, ep in candidates:
    if ep.queryParams.len == 0 and ep.bodySubstrings.len == 0:
      if fallbackIdx == -1:
        fallbackIdx = idx
      if 0 > bestScore:
        bestScore = 0
        bestIdx = idx
      continue

    var queryOk = true
    for k, v in ep.queryParams:
      if not reqQuery.hasKey(k) or reqQuery[k] != v:
        queryOk = false
        break
    if not queryOk:
      continue

    var bodyOk = true
    for s in ep.bodySubstrings:
      if s notin reqBodyRaw:
        bodyOk = false
        break
    if not bodyOk:
      continue

    let score = ep.queryParams.len + ep.bodySubstrings.len
    if score > bestScore:
      bestScore = score
      bestIdx = idx

  if bestIdx != -1:
    return candidates[bestIdx]
  if fallbackIdx != -1:
    return candidates[fallbackIdx]
  return default404Endpoint()

proc parseMethod*(methodStr: string): types.HttpMethod =
  let upperMethod = methodStr.toUpperAscii()
  case upperMethod
  of "GET": hmGet
  of "POST": hmPost
  of "PUT": hmPut
  of "DELETE": hmDelete
  of "PATCH": hmPatch
  of "HEAD": hmHead
  of "OPTIONS": hmOptions
  else: hmGet

proc handleRequest(req: Request) {.async.} =
  let reqMethod = parseMethod($req.reqMethod)
  let reqPath = decodeUrl(req.url.path)

  # Parse query params ?k1=v1&k2=v2
  let reqQueryRaw = decodeUrl(req.url.query)
  var reqQueryParams = initTable[string, string]()
  if reqQueryRaw.len > 0:
    for pair in reqQueryRaw.split("&"):
      let parts = pair.split("=", maxsplit=1)
      if parts.len == 2:
        reqQueryParams[parts[0].strip()] = decodeUrl(parts[1].strip())
      elif parts.len == 1 and parts[0].len > 0:
        reqQueryParams[parts[0].strip()] = ""

  # Use raw body string for substring matching
  let reqBodyRaw = $req.body

  let endpoint = findEndpoint(reqMethod, reqPath, reqQueryParams, reqBodyRaw)

  # Apply delay if configured
  if endpoint.delayMs > 0:
    await sleepAsync(endpoint.delayMs)

  # Build response headers
  var headers = newHttpHeaders()
  for key, value in endpoint.headers:
    headers[key] = value

  # Add CORS headers for frontend usage
  headers["Access-Control-Allow-Origin"] = "*"
  headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, PATCH, OPTIONS"
  headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

  await req.respond(endpoint.statusCode.HttpCode, endpoint.responseBody, headers)

proc startServer*(config: MockConfig) =
  globalConfig = config

  var server = newAsyncHttpServer()

  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║           Mockim - Mock RESTful API Server                   ║"
  echo "╠══════════════════════════════════════════════════════════════╣"
  echo "║  Server: http://", config.host, ":", config.port, " "
  echo "║                                                              ║"
  echo "║  Endpoints:                                                  ║"
  for ep in config.endpoints:
    let methodStr = $ep.methodType
    let pathStr = ep.path
    let descStr = if ep.desc.len > 0: " (" & ep.desc & ")" else: ""
    let line = methodStr & " " & pathStr & descStr
    if line.len > 56:
      echo "║    ", line.substr(0, 52), "... ║"
    else:
      let padding = max(0, 56 - line.len)
      echo "║    ", line, " ".repeat(padding), "║"
  echo "╚══════════════════════════════════════════════════════════════╝"

  let handler = proc (req: Request): Future[void] {.closure, gcsafe.} =
    handleRequest(req)
  waitFor server.serve(Port(config.port), handler, config.host)
