require 'rpc'

local p1 = rpc.createproxy (IP, porta1, arq_interface)
local p2 = rpc.createproxy (IP, porta2, arq_interface)
local r, s = p1.foo(3, 5)
local t = p2.boo(10)
