import std/tables

type
  HttpMethod* = enum
    hmGet = "GET"
    hmPost = "POST"
    hmPut = "PUT"
    hmDelete = "DELETE"
    hmPatch = "PATCH"
    hmHead = "HEAD"
    hmOptions = "OPTIONS"

  ApiEndpoint* = object
    methodType*: HttpMethod
    path*: string
    desc*: string
    statusCode*: int
    responseBody*: string
    delayMs*: int
    headers*: Table[string, string]
    queryParams*: Table[string, string]
    bodySubstrings*: seq[string]


  MockConfig* = object
    endpoints*: seq[ApiEndpoint]
    port*: int
    host*: string