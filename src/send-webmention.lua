
-- 
local function get_href(str, search)
  local t = {}
  -- search for tag that contains searched text
  local newsearch = "<([^>]-" .. search .. "[^>]-)>"
  for match in str:gmatch(newsearch) do
    local url = match:match("href%s*=%s*[\"'](.-)[\"']")
    table.insert(t, url)
  end
  return t
end

local function curl(url)
  local command = io.popen("curl -A 'Mozilla/5.0 rdrview/0.1' -sS '".. url.. "'","r")
  if not command then return nil, "Cannot run curl" end
  local content = command:read("*all")
  command:close()
  return content
end

-- read webmention source from stdin
local str = io.read("*all")

-- find webmention destination
local url = get_href(str, "u%-in%-reply%-to")
-- exit if we cannot find dest url
if not url[1] then
  print("Cannot find URL in input")
  print(url[1])
  os.exit(1)
end

-- try to find webmention endpoind in the mentioned page
for _, u in ipairs(url) do 
  local content, msg = curl(u)
  if not content then
    print(msg)
    print(u)
    os.exit(1)
  end

  -- this regex starts to be ugly :/
  local endpoint = get_href(content, "rel%s*=%s*[\"'][^\"^']-webmention")

  print("Found webmention endpoints")
  for _, url in ipairs(endpoint) do
    print(url)
    -- send webmention:
    -- curl -i -d "source=$your_url&target=$target_url" $targets_webmention_endpoint
  end
end


