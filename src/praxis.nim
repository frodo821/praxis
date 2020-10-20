import asyncdispatch, macros
import ./praxis/http
import ./praxis/routing

export asyncdispatch
export http
export routing except dispatch

macro run*(host: string = "localhost", port: 1..65535 = 8080, maxHandlers: int = 10000) =
  let hostStr = host.strVal
  let portNum = port.intVal
  let maxHandlersNum = maxHandlers.intVal

  quote do:
    proc main() {.inject.} =
      dispatch()

      let server = createServer(
        address = `hostStr`,
        port = `portNum`,
        maxHandlers = `maxHandlersNum`)

      asyncCheck server.serve(callback)
      runForever()

    when isMainModule:
      main()
