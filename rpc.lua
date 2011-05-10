local socket, dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert =
      require("socket"), dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert


--modulo rpc
module(..., package.seeall);


servants 	= { }
proxies 	= { }
limit 		= 5
debug		= true
metatable 	= {

	__call = function (t,...)

		-- checagem de tipos de dados
		--typeCheck(t,...)

		-- realiza marshalling dos dados
		--local request = marshall(t.name[1],...)
		
		logger("__call: ",t.name[1], ...)

		-- transmite dados
		--return handeCall(t,request)
	end
}

--funções "públicas" do módulo

function rpc.createServant(impl, idlfile, port)
	-- cria socket tcp e faz bind para porta >= 55000
	local _port = port or 55000+#rpc.servants
	local serversocket = assert(socket.bind("*", _port))

	--flag tcp-nodelay
	serversocket:setoption("tcp-nodelay", true)

	-- cria stub a partir da interface idl
	local stub = parseIDL(idlfile)

	--insere objs na tabela servants
	table.insert(servants, {stub, impl, serversocket})
	
	local ip, port = serversocket:getsockname()
	logger("createServant", "ip: " .. ip, "port: " .. port)

	return stub
end

function rpc.createProxy(obj, idlfile, port)
	-- reading the file
	local file = assert(io.open(filename,"r"))
	local interface = file:read("*all")
	file:close()
	
	-- stablishing connection and creating a proxy table
	local proxy = { _conn = nil, _ip = ip, _port = port, _conn_type = conn_type }
	table.insert(proxies,proxy)

	-- call the interface parser
	return parser(proxy,interface)


end

function rpc.waitIncoming()


end




--funções auxiliares

function logger(...)
	if debug then
		print(...)
	end
end

function handleData(stub, request)

end

function handleConnection(socket)

end

function argTypeCheck()

end

function returnTypeCheck()

end

function marshall(...)

end

function unmarshall(...)

end

function invokeMethod(servant, request)
	--TODO
	--unmarshall
	--desempacota params (remove o primeiro, que o nome do metodo)
	--chama metodo no obj com a implementacao
	--marshall do resultado
	--retorna o resultado 
end

function parseIDL(idlfile)

	-- le arquivo da interface idl
	local file = assert(io.open(idlfile,"r"))
	local interface = file:read("*all")
	file:close()

	local name, methods
	local stub = {}

	--parsing do arquivo idl (OBS: só pode ter uma interface por arquivo .idl)
	local interface_match = string.gmatch(interface,"%s*interface%s*(%w+)%s*{([^{}]+)}%s*;%s*")
	name, methods = interface_match()

	logger('parseIDL: ', name)

	local method_match = string.gmatch(methods,"%s*(%a+)%s*(%w+)%s*\(.-\)%s*;")

	while (true) do

		-- parsing da definicao do metodo
		returntype,method,param = method_match()
		if (returntype == nil or method == nil or param == nil) then
			break
		end


		--tabela deste metodo no stub
		stub[methods] = {
			name = { method },
			result = { returntype },
			args = {}
		}

		setmetatable(stub[methods],metatable)

		--imprime metodos
		logger('parseIDL: ', "return: " .. returntype, "method: " .. method, "param: " .. param)

		-- recupera string entre parenteses
		_,_,tmp = string.find(param,"%((.*)%)")

		-- parsing das assinaturas dos metodos
		local signature_match = string.gmatch(tmp,"%s*(%w+)%s*(%w+)%s*(%w+)%s*%p?")
		while (true) do
			direction,paramtype,argname = signature_match();

			if (direction == nil or paramtype == nil or argname == nil) then
				break
			end
			
			--insere os metodos no stub
			stub[methods].args[#stub[methods].args+1] = { direction=direction, type=paramtype }

			--caso a direcao do parametro seja out ou inout adiciona como resultado
			if(direction == "out" or direction == "inout") then
				table.insert(stub[methods].result, paramtype)
			end

			logger('parseIDL: ', "arg: " .. #stub[methods].args, "direction: " .. direction, "type: " .. paramtype)
		end

	end

	return stub

end



