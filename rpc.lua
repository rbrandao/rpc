--declaração local dos módulos que queremos ter acesso
local socket, dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert =
      require("socket"), dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert


--definição do modulo rpc
module(..., package.seeall);

--tabelas do módulo
servants 	= { }
proxies 	= { }
sockets 	= { }

limit 		= 5
debug		= true

--tabela que será utilizada na chamada setmetatable para possibilitar o tratamento 
--antes e depois das chamadas dos métodos dos stubs
metatable 	= {

	__call = function (t,...)

		logger("__call: ",t.name)

		-- checagem de tipos de dados
		checkedArgs = argsTypeCheck(t,...)

		-- realiza serializing dos dados
		local request = serialize(t.name,checkedArgs)
		
		-- tratamento da chamada
		local ret = handleData(t,request)

		--return deserialize(request)
	end
}


----------------------------------
-- funções "públicas" do módulo --
----------------------------------

------------------------------------------------------------------
-- rpc.createServant()
--
-- Cria servant no lado do servidor
-- Parâmetros: 
-- impl: objeto com a implementação a ser utilizada pelo servant
-- idlfile: path para o arquivo.idl com a definiçãõ das interfaces
-- port: porta (opcional) a ser utilizada para o bind do servidor
--
-- Retorno:
-- Stub que reflete a definição do arquivo.idl
------------------------------------------------------------------
function rpc.createServant(impl, idlfile, port)
	-- cria socket tcp e faz bind para porta >= 55000
	local _port = port or 55000+#rpc.servants
	local serversocket = assert(socket.bind("*", _port))

	-- flag tcp-nodelay
	serversocket:setoption("tcp-nodelay", true)
	table.insert(sockets, serversocket)

	-- cria stub a partir da interface idl
	local stub = parseIDL(idlfile)

	-- insere impl do servant na tabela
	table.insert(servants, impl)

	-- insere stub e impl indexado pelo socket para acesso direto
	servants[serversocket] = { }
	table.insert(servants[serversocket], {stub, impl})
	
	local ip, port = serversocket:getsockname()
	logger("createServant", "port: " .. port)

	return stub
end

------------------------------------------------------------------
-- rpc.waitIncoming()
--
-- Faz com que o servidor entre no laço de espera por novas 
-- conexões e atendimento de clientes
------------------------------------------------------------------
function rpc.waitIncoming()

	while true do
	
		--TODO
		logger("waitIncoming", "aguardando requisições")
		local read, write, err = socket.select(sockets)
		logger("waitIncoming", "requisicoes recebidas:" .. #read)

		--trata requisicoes
		for i=1, #read do
			--socket sendo tratado
			socket = #read[i]

			--servant existe
			if servants[socket] then

				--recebe requisicao
				--req, err = socket:receive("*l")
				--
				--if req == nil then
				--closeConnection()
				--end

				handleData(servants[socket])
			else
				--trata nova conexao
				handleConnection(socket)
			end
		end

	end

end

------------------------------------------------------------------
-- rpc.createProxy()
--
-- Cria proxy no lado do cliente
-- Parâmetros: 
-- ip: endereço ip do servidor
-- port: porta do servidor
-- idlfile: path para o arquivo.idl com a definição das interfaces
--
-- Retorno:
-- Stub que reflete a definição do arquivo.idl
------------------------------------------------------------------
function rpc.createProxy(ip, port, idlfile)
	-- cria tabela do proxy
	local proxy = { _ip = ip, _port = port, socket = nil }
	table.insert(proxies,proxy)

	-- cria stub a partir da interface idl
	local stub = parseIDL(idlfile)

	-- insere stub na tabela de proxies
	proxies[stub.name] = { }
	table.insert(proxies[stub.name], {stub=stub, proxy=proxy})
	
	return stub
end



--------------------------------------
-- funções auxiliares do módulo rpc --
--------------------------------------

------------------------------------------------------------------
-- logger()
--
-- Função para exibir ou não mensagens de debugging
-- Parâmetros: 
-- (...): uma ou mais strings para impressão
------------------------------------------------------------------
function logger(...)
	if debug then
		print(...)
	end
end

------------------------------------------------------------------
-- handleData()
--
-- Trata o despacho dos dados para o stub definido.
--
-- Parâmetros: 
-- stub: Stub que receberá a requisição
-- request: String com os dados serializados
--
-- Retorno:
-- Resultados desempacotadas (unpacked) dos dados deserializados
------------------------------------------------------------------
function handleData(stub, request)

	logger("handleData", "Tratando requisicao para: " .. stub.name .. " req: [" .. request .. "]")

	--TODO
end

------------------------------------------------------------------
-- handleConnection()
--
-- Trata a requisição de conexção de um novo cliente. O novo socket
-- será adicionado a tabela 'sockets' e deverá então ser tratado
-- no loop do servidor (após a chamada waitIncoming)
--
-- Parâmetros: 
-- socket: Socket do cliente
------------------------------------------------------------------
function handleConnection(socket)

	local ip, port = socket:getsockname()
	logger("handleConnection", "Tratando nova conexão para: " .. ip .. ":" .. port)

	--TODO

end

------------------------------------------------------------------
-- argsTypeCheck()
--
-- Função para verificar se os tipos dos parâmetros passados estão
-- de acordo. Caso haja alguma incompatibilidade que não possa ser
-- tratada a execução será abortada e um erro é apresentado através
-- da chamada 'assert'.
--
-- Parâmetros: 
-- stub: Stub que está sendo chamado
-- (...): Parâmetros de chamada
------------------------------------------------------------------
function argsTypeCheck(method, ...)
	local nargs=select('#', ...)
	local checkedArgs = {}

	logger("argsTypeCheck", "metodo: " .. method.name, "nargs:" .. #method.args)

	--verifica os tipos passados
	for i=1, #method.args do
		local checkedValue = nil
		local argvalue = select(i,...)
		logger("argsTypeCheck", "valor " .. i .. ": " .. tostring(argvalue), "recebido: " .. type(argvalue), "definição: " .. method.args[i].type)

		
		--verifica compatibilidade dos parametros
		if(method.args[i].type == "double" or method.args[i].type == "int" ) then
			
			--verifica ausencia do parametro
			if(type(argvalue) == "nil") then
				checkedValue = 0
				logger("argsTypeCheck", "parâmetro inexistente: " .. method.args[i].name, "valor atribuído: " .. checkedValue)
			else
				--caso exista verifica o tipo
				assert(type(argvalue) == "number", "parâmetro inválido: " .. type(argvalue) .. " (definição: number)")
			end


		elseif(method.args[i].type == "string" or method.args[i].type == "char") then

			--verifica ausencia do parametro
			if(type(argvalue) == "nil") then
				checkedValue = "nil"
				logger("argsTypeCheck", "parâmetro inexistente: " .. method.args[i].name, "valor atribuído: \""..checkedValue.."\"")
			else
				--caso exista verifica o tipo
				assert(type(argvalue) == "string", "parâmetro inválido: " .. type(argvalue) .. " (definição: string)")
			end
		end
	
		--insere parametro checado, com valor default caso ele nao tenha sido passado
		table.insert(checkedArgs, checkedValue or argvalue)
		logger("argsTypeCheck", "inserindo " .. (checkedValue or argvalue))
	end
			
	logger("argsTypeCheck", unpack(checkedArgs))

	return checkedArgs
end

------------------------------------------------------------------
-- returnTypeCheck()
--
-- Função para verificar se os tipos dos valores retornados estão
-- de acordo. Caso haja alguma incompatibilidade que não possa ser
-- tratada a execução será abortada e um erro é apresentado. Através
-- da chamada 'assert'.
--
-- Parâmetros: 
-- stub: Stub que está sendo chamado
-- (...): Valores retornados
------------------------------------------------------------------
function returnTypeCheck(stub, ...)

	--TODO

end

------------------------------------------------------------------
-- serialize()
--
-- Função para serializar os dados de acordo com a especificação
-- do protocolo de transmissão
--
-- Parâmetros: 
-- method: Tabela do método
-- args: Parâmetros da chamada
--
-- Retorno:
-- String codificada, ex: "metodo\narg1\narg2\narg3"
------------------------------------------------------------------
function serialize(method,args)

	local str="" .. method .. "\n"
	
	for i=1,#args do

		local param=args[i]

		if(type(param)=="string") then
			param = string.gsub(param,"%\n","\\n")
			str=str .. param .. "\n"
		else
			str=str .. tostring(param) .. "\n"
		end
	end

	logger("serialize", "["..str.."]")

	return str
	
end

------------------------------------------------------------------
-- deserialize()
--
-- Função para deserializar os dados de acordo com a especificação
-- do protocolo de transmissão
--
-- Parâmetros: 
-- str: String codificada através da função de serialização
--
-- Retorno:
-- Lista com valores decodificados
------------------------------------------------------------------
function deserialize(str)
	local list = {}
	for word in string.gmatch(str, "%w+") do 
		table.insert(list,word)
		logger("deserialize", word)
	end

	return list
end

------------------------------------------------------------------
-- invokeMethod()
--
-- Função para invocar método em um determinado servant
--
-- Parâmetros: 
-- servant: Tabela com o servant que irá processar a chamada
-- request: Requisição que este servant irá processar
--
-- Retorno:
-- O valor retornado pela implementação do servant
------------------------------------------------------------------
function invokeMethod(servant, request)
	--TODO
	--deserialize
	--desempacota params (remove o primeiro, que o nome do metodo)
	--chama metodo no obj com a implementacao
	--serialize do resultado
	--retorna o resultado 
end

-----------------------------------------------------------------
-- parseIDL()
--
-- Função para realizar parsing de um arquivo IDL com definições
-- de interfaces (uma interface por arquivo)
--
-- Parâmetros: 
-- idlfile: Caminho para o arquivo.idl a ser analisado
--
-- Retorno:
-- Stub (tabela Lua) que reflete a interface IDL
------------------------------------------------------------------
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

	stub.name = name
	logger('parseIDL: ', name)

	local method_match = string.gmatch(methods,"%s*(%a+)%s*(%w+)%s*\(.-\)%s*;")

	while (true) do

		-- parsing da definicao do metodo
		returntype,method,param = method_match()
		if (returntype == nil or method == nil or param == nil) then
			break
		end


		--tabela deste metodo no stub
		stub[method] = { 
			name = method, 
			result = { returntype }, 
			args = { } 
		}

		--metatable dos metodos para possibilitar a chamada (__call)
		setmetatable(stub[method],metatable)

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
			stub[method].args[#stub[method].args+1] = { name=argname, direction=direction, type=paramtype }

			--caso a direcao do parametro seja out ou inout adiciona como resultado
			if(direction == "out" or direction == "inout") then
				table.insert(stub[method].result, paramtype)
			end

			logger('parseIDL: ', "arg: " .. argname, "direction: " .. direction, "type: " .. paramtype)
		end

	end

	return stub

end



