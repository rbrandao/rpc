require 'rpc'

local p1 = rpc.createProxy("127.0.0.1", 55000, "minhaInt.idl")
local p2 = rpc.createProxy("127.0.0.1", 55001, "minhaInt.idl")
local r, s = p1.foo(3, 5)
local t = p2.boo(10)

--print("p1: r="..r.." s"..s)
--print("p2: t="..t)
