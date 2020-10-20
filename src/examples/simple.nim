import strformat
import praxis

route get, "/{name}":
  await res
    .status(Http200)
    .header("Content-type", "text/html; charset=utf-8")
    .send(&"<h1>Hello, {name}</h1>")

route get, "/":
  await res
    .status(Http200)
    .header("Content-type", "text/html; charset=utf-8")
    .send("<h1>It works!</h1>")

route get, "/add/{num1: int}/{num2: int}":
  await res
    .status(Http200)
    .header("Content-type", "text/html; charset=utf-8")
    .send(&"<h1>{num1} + {num2} = {num1 + num2}</h1>")

run("0.0.0.0", 8080)
