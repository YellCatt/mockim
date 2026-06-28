import std/[os, strutils]

proc parseYamlConfig*(filepath: string): tuple[port: int, host: string, psvPath: string, found: bool] =
  result = (port: 8080, host: "0.0.0.0", psvPath: "", found: false)
  if not fileExists(filepath):
    return
  result.found = true

  let content = readFile(filepath)
  for rawLine in content.splitLines():
    var line = rawLine.strip()
    if line.len == 0 or line.startsWith("#"):
      continue

    # Remove inline comments that are not inside quotes
    var inQuote = '\0'
    var hashIdx = -1
    for i, c in line:
      if c == '"' or c == '\'':
        if inQuote == '\0':
          inQuote = c
        elif inQuote == c:
          inQuote = '\0'
      elif c == '#' and inQuote == '\0':
        hashIdx = i
        break
    if hashIdx != -1:
      line = line[0 ..< hashIdx].strip()

    let colonIdx = line.find(':')
    if colonIdx == -1:
      continue

    let key = line[0 ..< colonIdx].strip().toLowerAscii()
    var value = line[colonIdx + 1 .. ^1].strip()

    # Unwrap simple YAML quotes
    if value.len >= 2 and ((value[0] == '"' and value[^1] == '"') or
                           (value[0] == '\'' and value[^1] == '\'')):
      value = value[1 .. ^2]

    case key
    of "port":
      try:
        result.port = parseInt(value)
      except ValueError:
        discard
    of "host":
      result.host = value
    of "psv_path":
      result.psvPath = value
    else:
      discard
