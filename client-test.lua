require 'rpc'

local p1 = rpc.createProxy("127.0.0.1", 55000, "minhaInt.idl")
local p2 = rpc.createProxy("127.0.0.1", 55001, "minhaInt.idl")
local p3 = rpc.createProxy("127.0.0.1", 55001, "minhaInt.idl")
local p4 = rpc.createProxy("127.0.0.1", 55001, "minhaInt.idl")

local r, s = p1.foo(0, 1)
print("p1: r="..r.." s="..s)

local r2, s2 = p1.foo(1, 2)
print("p1: r2="..r2.." s2="..s2)

local r3, s3 = p1.foo(2, 3)
print("p1: r3="..r3.." s3="..s3)

local r4, s4 = p1.foo(3, 4)
print("p1: r4="..r4.." s2="..s4)


local t = p2.boo(1)
print("p2: t="..t)

local t2 = p2.boo(10)
print("p2: t2="..t2)

local t3 = p2.boo(100)
print("p2: t3="..t3)

print("p3: " .. p3.foo(0, 1))

print("p3: " .. p3.foo(1, 2))

print("p4: " .. p4.boo(10))

for i=1, 50 do
	print("p4: " .. p4.foo(10,20))
end

for i=1, 50 do
	print("p3: " .. p3.foo(10,20))
end

