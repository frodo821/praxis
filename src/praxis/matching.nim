import macros, re, strutils

let blockLabel {.compileTime.} = newIdentNode("judge")

proc varUnannotated(index: int, name: string): NimNode {.compileTime.} =
  let ident = block:
    if not name.validIdentifier:
      error "Invalid identifier: " & name
    newIdentNode(name)

  quote do:
    let `ident` = pathElements[`index`]

proc matchRe(index: int, ident: NimNode, pattern: string, captures: int = 0): NimNode {.compileTime.} =
  quote do:
    let `ident`: seq[string] = block:
      var matches: array[`captures`, string]
      if not match(pathElements[`index`], re `pattern`, matches):
        matched = false
        break `blockLabel`
      @matches

proc varAnnotatedWithType(index: int, name: string, `type`: string): NimNode {.compileTime.} =
  let ident = block:
    if not name.validIdentifier:
      error "Invalid identifier: " & name
    newIdentNode(name)
  
  if `type`.startsWith("re"):
    let regex = `type`[2..`type`.len - 1].rsplit(',', 1)

    if regex.len > 2:
      error "too much regex arguments."

    var captures = 0
    if regex.len == 2:
      captures = regex[1].strip.parseInt

    if not (regex[0].startsWith("\"") and regex[0].endsWith("\"")):
      error "invalid string literal"
    
    let pattern = regex[0]

    return matchRe(index, ident, pattern[1..pattern.len - 2], captures)

  case `type`
    of "bool":
      quote do:
        let `ident`: bool = try:
            parseBool(pathElements[`index`])
          except:
            matched = false
            break `blockLabel`
    of "int":
      quote do:
        let `ident`: int = try:
            parseInt(pathElements[`index`])
          except:
            matched = false
            break `blockLabel`
    of "hex":
      quote do:
        let `ident`: int = try:
            parseHexInt(pathElements[`index`])
          except:
            matched = false
            break `blockLabel`
    of "oct":
      quote do:
        let `ident`: int = try:
            parseOctInt(pathElements[`index`])
          except:
            matched = false
            break `blockLabel`
    of "float":
      quote do:
        let `ident`: float = try:
            parseFloat(pathElements[`index`])
          except:
            matched = false
            break `blockLabel`
    else:
      raise newException(ValueError, "unknown type identifier: " & `type`)

macro match*(expect, path: untyped): untyped =
  if expect.kind notin {nnkStrLit..nnkTripleStrLit}:
    error "path patterns are must be string literal."
  let pattern = block:
    var path = expect.strVal
    if path.startsWith('/'):
      path = path[1..path.len - 1]
    path.split('/')

  let conds = newStmtList()
  let vars = newStmtList()
  let patternLen = pattern.len

  for idx, patternElement in pattern:
    if patternElement.startsWith("{") and patternElement.endsWith("}"):
      let expr = patternElement[1..patternElement.len - 2]
      if ':' in expr:
        let elems = expr.split(':', 1)

        let rawNode = varAnnotatedWithType(idx, elems[0].strip, elems[1].strip)

        let ident = rawNode[0][0]
        let typ = rawNode[0][1]
        let assg = rawNode[0][2]

        let decl = quote do:
          var `ident`: `typ`

        let assign = quote do:
          `ident` = `assg`

        echo astGenRepr(decl)

        vars.add(decl)
        conds.add(assign)
        continue

      vars.add(varUnannotated(idx, expr.strip))
      continue

    let node = quote do:
      if `patternElement` != pathElements[`idx`]:
        matched = false
        break `blockLabel`

    conds.add(node)

  quote do:
    var matched {.inject.} = true
    let pathElements {.inject.} = block:
      var path = `path`
      if path.startsWith('/'):
        path = path[1..path.len - 1]
      path.split('/')

    `vars`
    block `blockLabel`:
      if pathElements.len < `patternLen`:
        matched = false
        break `blockLabel`
      `conds`
