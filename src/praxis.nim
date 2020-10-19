import asyncdispatch
import ./praxis/http
import ./praxis/routing
export routing except dispatch

proc run*(host: string, port: 1..65535, maxHandlers: int) =
  proc cb(req: Request, res: Response) {.async, gcsafe.} =
    dispatch()

  let server = createServer(
    address = host,
    port = port,
    maxHandlers = maxHandlers)

  asyncCheck server.serve(cb)
  runForever()
