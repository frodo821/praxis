import asyncdispatch, macros, strutils
from algorithm import sorted
import ./http
import ./matching

var routing {.compileTime.}: seq[(int, NimNode)] = newSeq[(int, NimNode)]()

proc calculatePriority(elements: seq[string]): int =
  result = 0
  for elem in elements:
    result = result shl 2
    if elem == "":
      continue
    if ':' in elem:
      if "re" in elem:
        result += 1
        continue
      result += 2
      continue
    result += 3

macro route*(meths, path, body: untyped): untyped =
  template add(methos: set[HttpMethod], meth: string) =
    case meth
    of "get":
      methos.incl(HttpGet)
    of "post":
      methos.incl(HttpPost)
    of "delete":
      methos.incl(HttpDelete)
    of "put":
      methos.incl(HttpPut)
    of "head":
      methos.incl(HttpHead)
    of "patch":
      methos.incl(HttpPatch)
    else:
      error "unknown HTTP method: " & meth

  if meths.kind notin {nnkInfix, nnkIdent}:
    error "invalid method spec."

  var methods: set[HttpMethod]
  var current: NimNode = meths

  while current.kind == nnkInfix:
    current[0].expectIdent("|")
    current[1].expectKind({nnkInfix, nnkIdent})
    current[2].expectKind(nnkIdent)

    let meth = current[2].strVal.toLowerAscii()
    methods.add(meth)
    current = current[1]

  methods.add(current.strVal)

  let ident = genSym(nskProc)
  let req = newIdentNode("req")
  let res = newIdentNode("res")

  let priority = calculatePriority(path.strVal.split("/"))

  let calling = quote do:
    if await `ident`(`req`, `res`):
      return

  routing.add((priority, calling))

  quote do:
    proc `ident`(`req`: Request, `res`: Response): Future[bool] {.async, inline.} =
      if `req`.reqMethod notin `methods`:
        return false

      match `path`, `req`.url.path

      if not matched:
        return false
      `body`
      return true

macro dispatch*(): untyped =
  let req = newIdentNode("req")
  let res = newIdentNode("res")

  let sort = routing.sorted(proc (a, b: (int, NimNode)): int = b[0] - a[0])
  let body = newStmtList()

  for node in sort:
    body.add(node[1])

  quote do:
    proc callback(`req`: Request, `res`: Response) {.async, gcsafe, inject.} =
      `body`
