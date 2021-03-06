local http = require("socket.http")
local https = require("ssl.https")
local logger = require("logger")
local ltn12 = require("ltn12")
local socket = require('socket')
local socket_url = require("socket.url")

local InternalDownloadBackend = {}
local max_redirects = 5; --prevent infinite redirects

function InternalDownloadBackend:getResponseAsString(url, redirectCount)
    if not redirectCount then
        redirectCount = 0
    elseif redirectCount == max_redirects then
        error("InternalDownloadBackend: reached max redirects: ", redirectCount)
    end
    print("InternalDownloadBackend: url :", url)
    local request, sink = {}, {}
    request['sink'] = ltn12.sink.table(sink)
    request['url'] = url
    local parsed = socket_url.parse(url)
   print(table.concat(sink))
    local httpRequest = parsed.scheme == 'http' and http.request or https.request;
    local code, headers, status = socket.skip(1, httpRequest(request))

    if code ~= 200 then
        print("InternalDownloadBackend: HTTP response code <> 200. Response status: ", status)
        if code and code > 299 and code < 400  and headers and headers["location"] then -- handle 301, 302...
           local redirected_url = headers["location"]
           print("InternalDownloadBackend: Redirecting to url: ", redirected_url)
           return self:getResponseAsString(redirected_url, redirectCount + 1)
        else
           error("InternalDownloadBackend: Don't know how to handle HTTP response status: ", status)
        end
    end
   
    return table.concat(sink)
end

function InternalDownloadBackend:newResponse(url,path)
	local data = ""
	local function collect(chunk)
	  if chunk ~= nil then
	    data = data .. chunk
	    end
	  return true
	end

	local ok, statusCode, headers, statusText = http.request {
	  method = "GET",
	  url = url,
	  sink = collect
	}

	print("ok\t",         ok);
	print("statusCode", statusCode)
	print("statusText", statusText)
	print("headers:")
	for i,v in pairs(headers) do
	  print("\t",i, v)
	end
	
end

function InternalDownloadBackend:download(url, path)
   local response = self:getResponseAsString(url)
   local file = io.open(path, 'w')
   file:write(response)
   file:close()
end



return InternalDownloadBackend
