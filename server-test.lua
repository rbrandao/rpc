require 'rpc'

--for k,v in pairs(rpc) do
--	print(k,v)
--end



myobj1 = { 
	foo = function (a, b, s)
		return a+b, "alo alo"
	end,

	boo = function (n)
		return n
	end
}

myobj2 = { 
	foo = function (a, b, s)
		return a-b, "tchau"
	end,
	
	boo = function (n)
		return 1
	end
}

-- cria servidores
serv1 = rpc.createServant(myobj1, "minhaInt.idl")
serv2 = rpc.createServant(myobj2, "minhaInt.idl")

-- usa as infos retornadas em serv1 e serv2 para divulgar contato 
-- (IP e porta) dos servidores
-- ...

-- vai para o estado passivo esperar chamadas:
rpc.waitIncoming()

