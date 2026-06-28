import std/[os, strutils, tables]
import types

proc parseHttpMethod*(methodStr: string): HttpMethod =
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

proc parseQueryParams*(queryStr: string): Table[string, string] =
  result = initTable[string, string]()
  if queryStr.len == 0 or queryStr == "":
    return

  let pairs = queryStr.split(",")
  for pair in pairs:
    let trimmed = pair.strip()
    if trimmed.len == 0:
      continue
    let parts = trimmed.split("=", maxsplit=1)
    if parts.len == 2:
      result[parts[0].strip()] = parts[1].strip()

proc splitPsvLine*(line: string, sep: char = '|'): seq[string] =
  result = @[]
  var current = ""
  var inQuotes = false
  var i = 0
  while i < line.len:
    let c = line[i]
    if c == '"':
      if inQuotes and i + 1 < line.len and line[i + 1] == '"':
        # Escaped quote inside a quoted PSV field
        current.add('"')
        inc i, 2
      elif inQuotes:
        # Closing quote for a quoted PSV field
        inQuotes = false
        inc i
      elif current.len == 0:
        # Opening quote only if this is the start of the field
        inQuotes = true
        inc i
      else:
        # Preserve literal quotes in an unquoted field (e.g. JSON text)
        current.add(c)
        inc i
    elif c == sep and not inQuotes:
      result.add(current)
      current = ""
      inc i
    else:
      current.add(c)
      inc i
  result.add(current)

proc parseHeaders*(headerStr: string): Table[string, string] =
  result = initTable[string, string]()
  if headerStr.len == 0 or headerStr == "":
    return

  let pairs = headerStr.split(",")
  for pair in pairs:
    let trimmed = pair.strip()
    if trimmed.len == 0:
      continue
    let parts = trimmed.split(":", maxsplit=1)
    if parts.len == 2:
      result[parts[0].strip()] = parts[1].strip()

proc parsePsvFile*(filepath: string): MockConfig =
  result = MockConfig(
    endpoints: @[],
    port: 8080,
    host: "0.0.0.0"
  )

  let content = readFile(filepath)
  let lines = content.splitLines()

  if lines.len == 0:
    return

  let headerLine = lines[0]
  let headers = splitPsvLine(headerLine)

  var colIndices = initTable[string, int]()
  for i, h in headers:
    colIndices[h.strip().toLowerAscii()] = i

  let methodIdx = colIndices.getOrDefault("method", -1)
  let pathIdx = colIndices.getOrDefault("path", -1)

  if methodIdx == -1 or pathIdx == -1:
    raise newException(ValueError, "PSV file must contain 'method' and 'path' columns: " & filepath)

  let descIdx = colIndices.getOrDefault("desc", -1)
  let statusIdx = colIndices.getOrDefault("status", -1)
  let headersIdx = colIndices.getOrDefault("headers", -1)
  let responseIdx = colIndices.getOrDefault("response", -1)
  let requestIdx = colIndices.getOrDefault("request", -1)
  let delayIdx = colIndices.getOrDefault("delay_ms", -1)
  let queryIdx = colIndices.getOrDefault("query", -1)

  for i in 1 ..< lines.len:
    let line = lines[i].strip()
    if line.len == 0 or line.startsWith("#"):
      continue

    let cols = splitPsvLine(line)

    var endpoint = ApiEndpoint(
      methodType: parseHttpMethod(cols[methodIdx].strip()),
      path: cols[pathIdx].strip(),
      desc: "",
      statusCode: 200,
      responseBody: "",
      delayMs: 0,
      headers: initTable[string, string](),
      queryParams: initTable[string, string](),
      bodySubstrings: @[]
    )

    if descIdx != -1 and descIdx < cols.len:
      endpoint.desc = cols[descIdx].strip()

    if statusIdx != -1 and statusIdx < cols.len:
      let statusStr = cols[statusIdx].strip()
      if statusStr.len > 0:
        try:
          endpoint.statusCode = parseInt(statusStr)
        except ValueError:
          discard

    if headersIdx != -1 and headersIdx < cols.len:
      endpoint.headers = parseHeaders(cols[headersIdx].strip())

    # Ensure default Content-Type if not already specified (case-insensitive)
    var hasContentType = false
    for key in endpoint.headers.keys:
      if key.toLowerAscii() == "content-type":
        hasContentType = true
        break
    if not hasContentType:
      endpoint.headers["Content-Type"] = "application/json"
    if queryIdx != -1 and queryIdx < cols.len:
      endpoint.queryParams = parseQueryParams(cols[queryIdx].strip())

    if requestIdx != -1 and requestIdx < cols.len:
      let rawRequest = cols[requestIdx].strip()
      if rawRequest.len > 0:
        for piece in rawRequest.split("&&"):
          let trimmed = piece.strip()
          if trimmed.len > 0:
            endpoint.bodySubstrings.add(trimmed)

    if responseIdx != -1 and responseIdx < cols.len:
      var rawResponse = cols[responseIdx].strip()
      if rawResponse.len > 0:
        endpoint.responseBody = rawResponse
        endpoint.responseBody = endpoint.responseBody.replace("\\n", "\n")
        endpoint.responseBody = endpoint.responseBody.replace("\\t", "\t")
        endpoint.responseBody = endpoint.responseBody.replace("\\\"", "\"")

    if delayIdx != -1 and delayIdx < cols.len:
      let delayStr = cols[delayIdx].strip()
      if delayStr.len > 0:
        try:
          endpoint.delayMs = parseInt(delayStr)
        except ValueError:
          discard

    result.endpoints.add(endpoint)

proc discoverPsvFiles*(dir: string): seq[string] =
  result = @[]
  for path in walkDirRec(dir):
    if path.toLowerAscii().endsWith(".psv"):
      result.add(path)

proc parsePsvFiles*(filepaths: seq[string]): MockConfig =
  result = MockConfig(
    endpoints: @[],
    port: 8080,
    host: "0.0.0.0"
  )
  for filepath in filepaths:
    let cfg = parsePsvFile(filepath)
    result.endpoints.add(cfg.endpoints)

proc parsePsvFromPath*(target: string): MockConfig =
  if fileExists(target):
    return parsePsvFile(target)
  elif dirExists(target):
    let files = discoverPsvFiles(target)
    if files.len == 0:
      raise newException(ValueError, "No .psv files found in directory: " & target & ". Provide a PSV file or directory, e.g., mockim examples/")
    return parsePsvFiles(files)
  else:
    raise newException(ValueError, "PSV file or directory not found: " & target)
