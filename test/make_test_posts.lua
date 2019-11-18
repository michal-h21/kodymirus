-- create bunch of posts for testing



local function build_post(filename, header, text) 
  local f = io.open(filename, "w")
  f:write(header)
  f:write(text)
  f:close()
end

local function generate_name(names, min, max)
  local name_len = math.random(max - min) + min 
  local new_name = {}
  for i = 1, name_len do 
    local next_word = math.random(#names) 
    new_name[#new_name+1] = names[next_word]
  end
  return new_name
end
  
local function make_filename(name, time)
  return os.date("%Y-%m-%d-", time) .. table.concat(name, "-")
end

local function generate_posts(file_root, count, names, categories, current_time)
  for i = 1, count do
    local new_time = current_time + math.random(1024) * 24 * 3600
    local new_name = generate_name(names, 2, 6)
    local filename = file_root .. make_filename(new_name, new_time) .. ".html"
    local date = os.date("%Y-%m-%d %H:%M:%S", new_time)
    local category = categories[math.random(#categories)]
    -- sample text
    local text = table.concat(generate_name(names, 399, 699), " ")
    local header = string.format(
[[---
layout: 'post'
title: '%s'
abstract: '<p>hello abstract</p>'
time: %i
date: '%s'
category: '%s'
styles: 
  - '/test.css'
---

]], table.concat(new_name, " "), new_time,  date, category)
    build_post(filename, header, "<p>" .. text .. "</p>")
  end
end


local categories = {"hello", "world", "test", "sample"}
-- words that will form the title
local names = "kodymirus is a problematic genus of early cambrian arthropod known from the czech republic which bears some resemblance to the eurypterids aglaspidids and chelicerates it is part of a small and low diversity fauna endemic to the area which dwelt in brackish waters"

local names_table = {}
local stop_words = {a=true, the=true}
for s in names:gmatch("%w+") do
  if not stop_words[s] then
    table.insert(names_table, s)
  end
end

local current_time  = os.time()
math.randomseed(current_time)

local file_root = "test/posts/"

generate_posts(file_root,524, names_table, categories, current_time)

-- os.execute("lua src/blog.lua " .. file_root)
