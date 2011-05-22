--declaração local dos módulos que queremos ter acesso
local socket, dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert =
      require("socket"), dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert


--definição do modulo rpc
module(..., package.seeall);

--tabelas do módulo
servants 	  = { }
proxies 	  = { }
sockets 	  = { }
proxy_connections = { }

--tipo da conexao dos proxies (1=sob demanda, abre e fecha a conexao sempre; 2=mantem conexao aberta)
connection_type = 2

--limite de conexoes atendidas simultaneamente
limit 		= 3

--flag que define se as mensagens de debug devem ser exibidas
debug		= false

--tabela que será utilizada na chamada setmetatable para possibilitar o tratamento 
--antes e depois das chamadas dos métodos dos stubs
metatable 	= {

	__call = function (t,...)

		logger("__call:", t.name)

		-- checagem de tipos de dados
		checkedArgs = argsTypeCheck(t,...)

		-- realiza serializing dos dados
		local request = serialize(t.name,checkedArgs)
	
		-- envia dados pro servidor e retorna valores obtidos
		return handleDataDispatch(t,request)
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
	
	--local interface_file = io.open(idlfile)
	--local stub = loadstring(" interface = function ( itable ) return itable end return " .. interface_file:read("*all"))()

	-- insere impl do servant na tabela
	table.insert(servants, impl)

	-- insere stub e impl indexado pelo socket para acesso direto
	servants[serversocket] = { }
	table.insert(servants[serversocket], stub)
	table.insert(servants[serversocket], impl)
	
	local ip, port = serversocket:getsockname()
	logger("createServant", "aguardando conexões na porta: " .. port)

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
			sock = read[i]
			local ip, port = sock:getsockname()

			if(servants[sock]) then
				logger("waitIncoming", "tratando nova conexao para servant")
				handleClientConnection(sock)
			else
				logger("waitIncoming", "atendendo requisicao na porta " .. port .. " (cliente previamente conectado)")

				--identifica metodo da requisicao
				meth, err = sock:receive("*l")

				if(meth ~= nil) then
					logger("waitIncoming", "metodo recebido: "..meth)

					request = meth .. "\n"

					--while(true) do
					local stub = proxy_connections[sock][1]
					for i=1, #stub[meth].args do
						local param,err=sock:receive("*l")

						if param == nil then
							break
						end

						logger("waitIncoming", "param recebido: " .. param)

						request = request .. param .. "\n"
					end

					logger("waitIncoming", "recebida requisicao (cliente previamente conectado): " .. "["..request.."]")

					--invoca metodo no servant
					if(proxy_connections[sock]) then
						local ret = invokeMethod(proxy_connections[sock],request)
						logger("handleClientConnection", "respondendo: ","["..ret.."]")
					
						--retorna valor para o cliente
						sock:send(ret)
					end

				else
					logger("waitIncoming", "fechando conexão: ",#servants+1,err,err2)
					local s = sockets[#servants+1]
					s:close()
					proxy_connections[sock][1] = nil
					proxy_connections[sock][2] = nil
					table.remove(sockets,#servants+1)
				end
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
	local proxy = { _ip = ip, _port = port, _socket = nil }
	
	-- cria stub a partir da interface idl
	local stub = parseIDL(idlfile, proxy)
	
	-- insere stub na tabela de proxies
	proxies[stub.name] = { }
	table.insert(proxies[stub.name], proxy)

	logger("createProxy",stub.name, proxy._ip)
	
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
-- handleDataDispatch()
--
-- Trata o despacho dos dados através do proxy definido.
--
-- Parâmetros: 
-- stub: Proxy que receberá a requisição
-- request: String com os dados serializados
--
-- Retorno:
-- Resultados desempacotadas (unpacked) dos dados deserializados
------------------------------------------------------------------
function handleDataDispatch(stub, request)

	logger("handleDataDispatch", "enviando requisicao: " .. stub.name .. " req: [" .. request .. "]" )

	assert(stub.proxy ~= nil, "handleDataDispatch: proxy é nulo! (stub.name=" .. stub.name ..")")

	local ip = stub.proxy._ip
	local port = stub.proxy._port
	local sock = stub.proxy._socket

	logger("handleDataDispatch", ip,port,sock)

	--cria conexao do proxy com o servidor
	if(sock == nil) then 
		logger("handleDataDispatch", "criando conexão: " .. ip .. ":" .. port)
		stub.proxy._socket = assert(socket.connect(ip,port))
		stub.proxy._socket:setoption("tcp-nodelay", true)
		stub.proxy._socket:setoption("reuseaddr", true)
		sock = stub.proxy._socket
	end

	assert(sock ~= nil, "a conexão não foi estabelecida!")

	--envia requisicao
	ret,err=sock:send(request)
	if(err=="closed") then
		logger("handleDataDispatch", "conexão fechada, reenviando...")
		sock:close()

		stub.proxy._socket = nil
		handleDataDispatch(stub, request)
	end

	--aguarda retorno dos dados
	logger("handleDataDispatch", "aguardando resposta do servidor")
	local status, err = sock:receive("*l")

	if(err=="closed") then
		logger("handleDataDispatch", "conexão fechada, reenviando...")
		sock:close()

		stub.proxy._socket = nil
		handleDataDispatch(stub, request)
	end


	--verifica estado de erro da chamada
	assert(status=="0", "handleDataDispatch: metodo " .. stub.name .. " retornou estado de erro: " .. tostring(err))

	--tabela com resultados da chamada
	local results = {}

	--le os resultados linha a linha
	for i=1, #stub.result do 
		local req2, err = sock:receive("*l")

		table.insert(results,req2)
		logger("handleDataDispatch", "param recebido: "..req2)

	end

	--mantem a conexao aberta ou fecha de acordo com a politica definida
	if(connection_type==1) then

		logger("handleDataDispatch", "fechando conexão! (política sob-demanda)")
		sock:close()
		proxy_connections[sock] = nil
		stub.proxy._socket = nil
	end

	return unpack(results)

end

------------------------------------------------------------------
-- handleClientConnection()
--
-- Trata a requisição de conexção de um novo cliente. O novo socket
-- será adicionado a tabela 'sockets' e deverá então ser tratado
-- no loop do servidor (após a chamada waitIncoming)
--
-- Parâmetros: 
-- socket: Socket do cliente
------------------------------------------------------------------
function handleClientConnection(sock)

	-- aceita pedido de conexao
	local client = sock:accept()

	--imprime ip e porta
	local ip, port = sock:getsockname()
	logger("handleClientConnection", "Tratando conexão na porta:" .. port)

	--identifica metodo da requisicao
	meth, err = client:receive("*l")
	logger("handleClientConnection", "metodo recebido: "..meth)

	local stub = servants[sock][1]
	local impl = servants[sock][2]
	local req = "" .. meth .. "\n"

	--le os parametros linha a linha
	for i=1, #stub[meth].args do 
		local req2, err = client:receive("*l")

		req = req .. req2 .. "\n"
		logger("handleClientConnection", "param recebido: "..req2)

	end

	-- chama método
	local ret = invokeMethod(servants[sock],req)
	logger("handleClientConnection", "respondendo: ","["..ret.."]")

	client:send(ret)

	-- insere socket do cliente na lista de conexoes
	table.insert(sockets, client)
	proxy_connections[client] = { }
	table.insert(proxy_connections[client], servants[sock][1])
	table.insert(proxy_connections[client], servants[sock][2])

	--limite de conexoes atingido
	local clients = #sockets - #servants
	if(clients > limit) then
		print("handleClientConnection", "número máximo de clientes atingido: limite=" .. limit .. " clientes=" .. clients )
		
		--remove primeiro socket ser de servants
		sockets[#servants+1]:close()
		table.remove(sockets,#servants+1)
	
		clients = #sockets - #servants
		print("handleClientConnection", "fechando conexão, total de clientes: " .. clients .. " (" .. #servants .. " servants e "..clients.." clientes)")

	else
		print("handleClientConnection", "clientes em atendimento: limite=" .. limit .. " clientes=" .. clients)
	end

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
-- method: Tabela do stub com método que está sendo chamado
-- results: Tabela com valores retornados
------------------------------------------------------------------
function returnTypeCheck(method, results)

	logger("returnTypeCheck", "verificando valores retornados para: " .. method.name)
	for i=1,#results do
		logger("returnTypeCheck", "return " ..i ..": "..results[i])
	end

	for i=1,#method.result do
		logger("returnTypeCheck", "esperado " .. i .. ": " .. method.result[i])
	end

	local nresults = #method.result
	--assert(results.n==nresults, "returnTypeCheck: número de valores retornados do servant incompatível: " .. unpack(results) .. " (esperado: " .. unpack(method.result)..")")

	for i=1,nresults do
		--logger("returnTypeCheck", "valor retornado: " .. type(results[i]) .. " esperado: " .. method.result[i])

		if ((method.result[i] == "int") or (method.result[i] == "double")) then
			assert( type(results[i]) == "number", "returnTypeCheck: retorno do método " .. method.name .. ": arg"..i.. " (" .. type(results[i])..")" .. " esperado: number")
		
		elseif ((method.result[i] == "string") or (method.result[i] == "char")) then
			assert( type(results[i]) == "string", "returnTypeCheck: retorno do método " .. method.name .. ": arg"..i.. " (" .. type(results[i]) ..")" .. " esperado: string")

		end
	end
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
-- request: String com a requisição que este servant irá processar
--
-- Retorno:
-- O valor retornado pela implementação do servant já serializado
------------------------------------------------------------------
function invokeMethod(servant, request)
	function pack(...)
		return arg
	end

	--deserializa requisicao
	local list = deserialize(request)

	--remove primeiro item (nome do metodo)
	local meth = table.remove(list,1)
	logger("invokeMethod", "chamando método: " .. meth)

	--verifica existencia do metodo
	local stub = servant[1]
	local impl = servant[2]
	local ret = {}

	if(impl[meth]==nil) then
		logger("invokeMethod", "método inexistente no servant (" .. meth ..")")

		--retorna erro (zero)
		return "1"
	else
		--agrupa todos os retornos da chamada
		ret = pack(impl[meth](unpack(list)))
	end


	--checa os valores retornos
	returnTypeCheck(stub[meth], ret)

	return serialize("0",ret)
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
function parseIDL(idlfile, proxy)

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
			result = { }, 
			args = { },
			proxy = proxy or { }, 
		}
		--insere valor de retorno
		if(returntype ~= "void") then
			table.insert(stub[method].result, returntype)
		end


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



