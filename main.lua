local DataStorage = require("datastorage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local ltn12 = require("ltn12")
local DEBUG = require("dbg")
local _ = require("gettext")
local json = require("json")
local http = require("socket.http")
local https = require("ssl.https")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local DownloadBackend = require("internaldownloadbackend")
local Device = require("device")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local turbo = require("turbo")
local httpclient = require("httpclient")
local InputDialog = require("ui/widget/inputdialog")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local Button = require("ui/widget/button")

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
int remove(const char *);
int rmdir(const char *);
]]

require("ffi/zeromq_h")


local WLNReader = InputContainer:new{
    name = "wlnreader",
    is_doc_only = false,
    results = {},
    path = {}
}




function WLNReader:init()
    self.ui.menu:registerToMainMenu(self)

end

function WLNReader:addToMainMenu(menu_items)
    menu_items.wlnreader = {
        text = _("WLN Reader"),
        sub_item_table = {
            {
                text_func = function()
                    return  _("Search")
                end,
                callback = function()
		     WLNReader: searchInput()                
                end
            },
            {
                text_func = function()
                    return  _("Next chapter")
                end,
                callback = function()
                local ReaderUI = require("apps/reader/readerui")
                last_dir, last_file = ReaderUI:getLastDirFile(true)
                print(last_dir)
                print(last_file)
                if string.find(last_dir,"wlnreader",1,true) ~= nil then
                
                firstsidindex =string.find(last_dir,'.(.',1,true)
                finalsidindex =string.find(last_dir,'.)',1,true)
                
                filen = string.sub(last_file,#last_file - #last_dir)
                firstsidindexu=string.find(filen,'.(.',1,true)
                finalsidindexu =string.find(filen,'.)',1,true)
                print(firstsidindexu)
                if (firstsidindex ~= nil and finalsidindex ~= nil and firstsidindexu ~= nil and finalsidindexu ~= nil )  then
                print(string.sub(last_dir,firstsidindex+3,finalsidindex-1))
                print(string.sub(filen,firstsidindexu+3,finalsidindexu-1))
                nsid = string.sub(last_dir,firstsidindex+3,finalsidindex-1)
                ncv = string.sub(filen,firstsidindexu+3,finalsidindexu-1)
                nstartvol = string.sub(ncv,1,string.find(ncv,"-",1,true)-1)
                nstartchap = string.sub(ncv,string.find(ncv,"-",1,true)+1)
                print(nsid)
                print(nstartvol)
                print(nstartchap)
                WLNReader:searchDetail(nsid,"next",nstartvol,nstartchap)
                end
                end
                     -- UIManager:show(InfoMessage:new{
                     	-- text = _("Hello, plugin world"),
                     	-- timeout = 3
            	      -- })
            	      
                end
            },
			{
                text_func = function()
                    return  _("Previous chapter")
                end,
                callback = function()
                local ReaderUI = require("apps/reader/readerui")
                last_dir, last_file = ReaderUI:getLastDirFile(true)
                print(last_dir)
                print(last_file)
                if string.find(last_dir,"wlnreader",1,true) ~= nil then
                
                firstsidindex =string.find(last_dir,'.(.',1,true)
                finalsidindex =string.find(last_dir,'.)',1,true)
                
                filen = string.sub(last_file,#last_file - #last_dir)
                firstsidindexu=string.find(filen,'.(.',1,true)
                finalsidindexu =string.find(filen,'.)',1,true)
                print(firstsidindexu)
                if (firstsidindex ~= nil and finalsidindex ~= nil and firstsidindexu ~= nil and finalsidindexu ~= nil )  then
                print(string.sub(last_dir,firstsidindex+3,finalsidindex-1))
                print(string.sub(filen,firstsidindexu+3,finalsidindexu-1))
                nsid = string.sub(last_dir,firstsidindex+3,finalsidindex-1)
                ncv = string.sub(filen,firstsidindexu+3,finalsidindexu-1)
                nstartvol = string.sub(ncv,1,string.find(ncv,"-",1,true)-1)
                nstartchap = string.sub(ncv,string.find(ncv,"-",1,true)+1)
                print(nsid)
                print(nstartvol)
                print(nstartchap)
                WLNReader:searchDetail(nsid,"prev",nstartvol,nstartchap)
                end
                end
                     -- UIManager:show(InfoMessage:new{
                     	-- text = _("Hello, plugin world"),
                     	-- timeout = 3
            	      -- })
            	      
                end
            },
        }
    }
end

function WLNReader:_makeJsonRequest(url, method, request_body)
    local sink = {}
    local source = ltn12.source.string(request_body)
    local respbody = {}
    http.request{
        url = url,
        method = method,
        sink = ltn12.sink.table(sink),
        source = source,
        headers = {
            ["Content-Length"] = #request_body,
            ["Content-Type"] = "application/json"
        }
    }

    if not sink[1] then
        error("No response from WLN Server")
    end
    -- print log from response body
    print(table.concat(sink))
    local response = json.decode(table.concat(sink))
   -- print("series id: ".. response.data.results[1].sid)
    if response.error then
        --error(response.error)
    end

    return response
end

function WLNReader:_makeHtmlRequest(url, method, request_body)
    local sink = {}
    local source = ltn12.source.string(request_body)
    local respbody = {}
    http.request{
        url = url,
        method = method,
        sink = ltn12.sink.table(sink),
        source = source,
        headers = {
            ["Content-Length"] = #request_body,
            ["Content-Type"] = "application/json"
        }
    }

    if not sink[1] then
        error("No response from WLN Server")
    end
    -- print log from response body
  -- print(table.concat(sink))
   

    return table.concat(sink)
end


function WLNReader:printSearchResult(title)
   -- get response from site
   -- local request_body = '{"mode" : "search-advanced","title-search-text" : "' .. title .. '"}'
    local request_body = '{"title": "'.. title ..'", "mode": "search-title"}'
    local url = "https://www.wlnupdates.com/api" 
    local responses = self:_makeJsonRequest(url, "POST", request_body)	
    --print("series id: ".. responses.data.results[1].sid)
    --- print results
    if (responses.error == false and #responses.data.results > 0)  then
   local WLNSearch = Menu:new{
    title = "Search results:",
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    no_title = false,
    parent = nil,
    } 
    self.results = {}
    	for i=1,#responses.data.results do
    	temp = {}
    		temp.text = responses.data.results[i].match[1][2]
    		temp.name = nil
                temp.callback = function()
                	 WLNReader.path = {""}
                	 print("passe")
                	 require("table")
                	 table.insert(WLNReader.path,title)
                	 print(WLNReader.path[2])
                	 print("passed")
                        WLNReader:searchDetail(responses.data.results[i].sid,"","","")
                        UIManager:close(WLNSearch)	
                end
    		print(temp.text)
    		table.insert(self.results, temp)
    	end
    	local items = #self.results
    WLNSearch:switchItemTable("Results", self.results , items, nil)  
    WLNSearch.paths = {"1"}
    function WLNSearch:onReturn()
    	WLNReader.path = {" "}
    	UIManager:close(WLNSearch)	
    	WLNReader: searchInput()   
    	print("ok return")
    	return true
    end
    
    
    UIManager:show(WLNSearch)	
    WLNSearch:onFirstPage()
    print("showed")
    else
     UIManager:show(InfoMessage:new{
                     	text = _("No novels found!"),
                     	timeout = 3,
            	      })
    WLNReader: searchInput()
    end
    return responses.id
end

function WLNReader:searchDetail(sid,mode,startvol,startchap)
   -- get response from site
   -- local request_body = '{"mode" : "search-advanced","title-search-text" : "' .. title .. '"}'
    targetchap = ""
    local request_body = '{"id": "'.. sid ..'", "mode": "get-series-id"}'
    local url = "https://www.wlnupdates.com/api" 
    local responses = self:_makeJsonRequest(url, "POST", request_body)	
    --print("series id: ".. responses.data.releases[1].srcurl)
    --- print results
    if #responses.data.releases > 0 then
   local WLNSearch2 = Menu:new{
    title = "Chapters:",
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    no_title = false,
    parent = nil,
    } 
    self.results = {}
    --print(type(responses.data.releases[6].chapter))
    --print(type(responses.data.releases[27].chapter)) 
    bruhx = #responses.data.releases
    print(#responses.data.releases)
    targetx = 1
    if (#responses.data.releases > 15 ) then k =#responses.data.releases  else k = #responses.data.releases end
    	for i=1, k do
    	temp = {}
    	

    	if type(responses.data.releases[i].volume) ~= "number" then vol = "" else vol = responses.data.releases[i].volume
		 end
    	if type(responses.data.releases[i].chapter) ~= "number" then chap = "" else chap = responses.data.releases[i].chapter
    	 end
    	        if (#mode > 0 and (vol == startvol or vol == tonumber(startvol)) and (chap == startchap or chap == tonumber(startchap))) then
    	        targetx = i
    	        print("found:"..targetx)
    	        end
    		temp.text = "Volume ".. vol .. ", Chapter " .. chap
    		temp.name = nil
                temp.callback = function()
                print("ok")
                
                if type(responses.data.releases[i].volume) ~= "number" then vol1 = "" else vol1 = 			responses.data.releases[i].volume end
    	if type(responses.data.releases[i].chapter) ~= "number" then chap1 = "" else chap1 = responses.data.releases[i].chapter end
    	
    		tempname = responses.data.title .." - ".. "Volume ".. vol1 .. ", Chapter " .. chap1
    		 responsesu = self:_makeHtmlRequest(responses.data.releases[i].srcurl, "GET", "")
    		 print(#responsesu)
    		 qstart = string.find(responsesu,"entry-content", 1, true)
    		 qend = string.find(responsesu,"entry-footer", 1, true)
    		 print(qstart)
    		 print(qend)
    		 if (qstart ~= nil and qend ~= nil) then
    		 cropped = string.sub(responsesu,qstart,qend)
    		 	if #cropped < 17000 then 
	    		 -- sus
	    		 lenx = '<a href="';
	    		 qstart = string.find(cropped,'<a href="', 1, true)
	    		 qend = string.find(cropped,'">', qstart, true)
	    		 --print(qstart)
	    		 if (qstart ~= nil and qend ~= nil) then
	    		 truelink = string.sub(cropped,qstart + #lenx,qend-1)
	    		 --print(truelink)
	    		 	if (truelink ~= nil and #truelink > 5) then 
	    		 	responses.data.releases[i].srcurl = string.sub(cropped,qstart + #lenx,qend-1)
	    		 	end
				end	
    		 	end
    		 end
    		-- print(string.find(responsesu,"entry-content", 1, true))
    		-- print(string.find(responsesu,"entry-footer", 1, true))
    		--print(responses.data.title)
                WLNReader:downloadEbook(responses.data.releases[i].srcurl,tempname,responses.data.title,sid,vol1 .."-"..chap1)
                
                end
    		print(temp.text)
    		table.insert(self.results, temp)
    	end
    	
    	local items = #self.results
    WLNSearch2.paths = {"1"} 	
    WLNSearch2:switchItemTable("Results", self.results , items, nil)
    if #mode == 0 then
    UIManager:show(WLNSearch2)
    else
      print("quick mode")
      
      if (mode == "next" and targetx > 1) then
       targetx = targetx - 1
	   end
      if (mode == "prev" and targetx < bruhx) then
       targetx = targetx + 1
      end 
	  print(targetx)
		  
          print(#responses.data.releases)
		  print(type(responses.data.releases[targetx].volume) )
         if type(responses.data.releases[targetx].volume) ~= "number" then vol1 = "" else vol1 = responses.data.releases[targetx].volume end
    	if type(responses.data.releases[targetx].chapter) ~= "number" then chap1 = "" else chap1 = responses.data.releases[targetx].chapter end
    	
    		tempname = responses.data.title .." - ".. "Volume ".. vol1 .. ", Chapter " .. chap1
    		 responsesu = self:_makeHtmlRequest(responses.data.releases[targetx].srcurl, "GET", "")
    		 print(#responsesu)
    		 qstart = string.find(responsesu,"entry-content", 1, true)
    		 qend = string.find(responsesu,"entry-footer", 1, true)
    		 print(qstart)
    		 print(qend)
    		 if (qstart ~= nil and qend ~= nil) then
    		 cropped = string.sub(responsesu,qstart,qend)
    		 	if #cropped < 17000 then 
	    		 -- sus
	    		 lenx = '<a href="';
	    		 qstart = string.find(cropped,'<a href="', 1, true)
	    		 qend = string.find(cropped,'">', qstart, true)
	    		 --print(cropped)
	    		 if (qstart ~= nil and qend ~= nil) then
	    		 truelink = string.sub(cropped,qstart + #lenx,qend-1)
	    		 --print(truelink)
	    		 	if (truelink ~= nil and #truelink > 5) then 
	    		 	responses.data.releases[targetx].srcurl = string.sub(cropped,qstart + #lenx,qend-1)
	    		 	end
				end	
    		 	end
    		 end
    		-- print(string.find(responsesu,"entry-content", 1, true))
    		-- print(string.find(responsesu,"entry-footer", 1, true))
    		--print(responses.data.title)
                WLNReader:downloadEbook(responses.data.releases[targetx].srcurl,tempname,responses.data.title,sid,vol1 .."-"..chap1)
   
    end
    
    function WLNSearch2:onReturn()
    print(#WLNReader.path)
    	local x = WLNReader.path[1]
    	local y = WLNReader.path[2]
    	WLNReader.path = {x,y}
    	UIManager:close(WLNSearch2)	
    	WLNReader:printSearchResult(WLNReader.path[2])
    	print("ok return")
    	return true
    end	
    WLNSearch2:onFirstPage()
    print("showed2")
    else 
     UIManager:show(InfoMessage:new{
                     	text = _("No chapters"),
                     	timeout = 3,
            	      })
     WLNReader:printSearchResult(WLNReader.path[2])       	      
    end
end




function WLNReader:downloadEbook(url,name,title,sid,vc)
local request_body = '{"title": "'.. name ..'", "urls": ["' .. url .. '"]}'
print(request_body)
local url2 = "https://epub.press/api/v1/books" 
local responses = self:_makeJsonRequest(url2, "POST", request_body)
print(responses.id)
download_id = responses.id
fulllink ="https://epub.press/api/v1/books/".. download_id .."/download?filetype=epub"
--DownloadBackend:download(fulllink, Device.home_dir .. "/wlnreader/"..name..".pdf")
WLNReader:_makeRequestGET("https://epub.press/api/v1/books/".. download_id .."/download", Device.home_dir .. "/wlnreader/"..title.." .(."..sid..".)/",name..".(."..vc..".).epub")
end

function WLNReader:_makeRequestGET(url, folder,fname)
    -- local sink = {}
    -- https.request{
        -- url = url,
        -- method = "GET",
        -- header = { ["Host"] = "epub.press" },
        -- sink = ltn12.sink.table(sink)
    -- }

    -- if not sink[1] then
        -- error("No response from WLN Server")
    -- end
    -- -- print log from response body
    -- print(table.concat(sink))
    
       for i=1,10 do
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
	print(type(data))
   	print(#data)
   	if #data > 1000 then
   	if not(FolderExists(Device.home_dir .. "/wlnreader/")) then
   	lfs.mkdir(Device.home_dir .. "/wlnreader/")
   	end
   	if not(FolderExists(folder)) then
	lfs.mkdir(folder)
	end
   	io.output(folder .. fname)
   	io.write(data)
   	io.close()
   	print("file downloaded")
   	
   	local ReaderUI = require("apps/reader/readerui")
        ReaderUI:showReader(folder .. fname)
        break
	end
	end
	
    return response
end

function WLNReader:searchInput()
 self.search_server_dialog = InputDialog:new{
        title = _("Search novel updates from WLNUpdates "),
        input = "",
        hint = _("Search string"),

        input_hint = _("Oregairu"),
        input_type = "string",
        description = _("Title of the novel:"),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(self.search_server_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        UIManager:close(self.search_server_dialog)
                        self:printSearchResult(self.search_server_dialog:getInputText()) 
                    end,
                },
            }
        },
    }
    UIManager:show(self.search_server_dialog)
    self.search_server_dialog:onShowKeyboard()
end

function FolderExists(strFolderName)
	if lfs.attributes(strFolderName:gsub("\\$",""),"mode") == "directory" then
		return true
	else
		return false
	end
end

return WLNReader

