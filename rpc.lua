--declaração local dos módulos que queremos ter acesso
local socket, dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert =
      require("socket"), dofile, ipairs, next, pairs, string, tonumber, tostring, unpack, gmatch, find, table, print, io, setmetatable, select, assert


--definição do modulo rpc
module(..., package.seeall);

--tabelas do módulo
servants 	= { }
proxies 	= { }
limit 		= 5
debug		= true

--tabela que será utilizada na chamada setmetatable para possibilitar o tratamento 
--antes e depois das chamadas aos stubs
metatable 	= {

	__call = function (t,...)

		-- checagem de tipos de dados
		--typeCheck(t,...)

		-- realiza marshalling dos dados
		--local request = marshall(t.name[1],...)
		
		logger("__call: ",t.name[1], ...)

		-- tratamento da chamada
		--return handleData(t,request)
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

------------------------------------------------------------------
-- rpc.waitIncoming()
--
-- Faz com que o servidor entre no laço de espera por novas 
-- conexões e atendimento de clientes
------------------------------------------------------------------
function rpc.waitIncoming()

	--while true do
	--TODO
	--end

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
	-- estabelece conexão com servidor e cria a tabela proxy
	--local proxy = { _conn = nil, _ip = ip, _port = port, }
	--table.insert(proxies,proxy)

	-- call the interface parser
	-- return parseIDL(idlfile)


end



----------------------------------
-- funções auxiliares do módulo --
----------------------------------


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
-- Trata o despacho dos dados para o stub definido. Este método 
-- deve serializar os dados (caso ja nao estejam), invocar o método 
-- definido na requisição e retornar os dados deserializados
--
-- Parâmetros: 
-- stub: Stub que receberá a requisição
-- request: String com os dados serializados
--
-- Retorno:
-- Resultados desempacotadas (unpacked) dos dados deserializados
------------------------------------------------------------------
function handleData(stub, request)

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

	--TODO

end

------------------------------------------------------------------
-- argsTypeCheck()
--
-- Função para verificar se os tipos dos parâmetros passados estão
-- de acordo. Caso haja alguma incompatibilidade que não possa ser
-- tratada a execução será abortada e um erro é apresentado. Através
-- da chamada 'assert'.
--
-- Parâmetros: 
-- stub: Stub que está sendo chamado
-- (...): Parâmetros de chamada
------------------------------------------------------------------
function argsTypeCheck(stub, ...)

	--TODO

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
-- marshall()
--
-- Função para serializar os dados de acordo com a especificação
-- do protocolo de transmissão
--
-- Parâmetros: 
-- (...): Parâmetros da chamada
--
-- Retorno:
-- String codificada, ex: "metodo\narg1\narg2\narg3"
------------------------------------------------------------------
function marshall(...)

	--TODO
end

------------------------------------------------------------------
-- unmarshall()
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
function unmarshall(str)

	--TODO
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
	--unmarshall
	--desempacota params (remove o primeiro, que o nome do metodo)
	--chama metodo no obj com a implementacao
	--marshall do resultado
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



