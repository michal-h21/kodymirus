-- Given a doc list, will generate an Atom feed file.
-- Can be used as a plugin, or as a helper for a theme plugin.

local transducers = require("lettersmith.transducers")
local into = transducers.into
local map = transducers.map
local take = transducers.take
local comp = transducers.comp

local wrap_in_iter = require("lettersmith.plugin_utils").wrap_in_iter

local lustache = require("lustache")

local docs = require("lettersmith.docs_utils")
local derive_date = docs.derive_date
local reformat_yyyy_mm_dd = docs.reformat_yyyy_mm_dd

local exports = {}

-- Atom uses ISO 8601 timestamps, e.g. 2025-10-08T10:00:00Z
local function to_iso8601(date_table)
  -- Takes os.time() or a date string, returns ISO 8601 UTC string
  return os.date("!%Y-%m-%dT%H:%M:%SZ", date_table)
end

-- Atom XML template
local atom_template_string = [[
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>{{site_title}}</title>
  <subtitle>{{site_description}}</subtitle>
  <link href="{{{site_url}}}" />
  <link href="{{{feed_url}}}" rel="self" />
  <updated>{{feed_updated}}</updated>
  <id>{{{site_url}}}</id>
  <author>
    <name>{{author_name}}</name>
    {{#author_email}}<email>{{author_email}}</email>{{/author_email}}
  </author>
  <generator>Lettersmith</generator>

  {{#items}}
  <entry>
    {{#title}}<title>{{title}}</title>{{/title}}
    <link href="{{{url}}}" />
    <id>{{{guid}}}</id>
    <updated>{{updated}}</updated>
    <published>{{pubdate}}</published>
    {{#author}}<author><name>{{author}}</name></author>{{/author}}
    {{#summary}}<summary type="html"><![CDATA[{{{summary}}}]].. "]]" .. [[></summary>{{/summary}}
    <content type="html"><![CDATA[{{{contents}}}]] .. "]]" .. [[></content>
  </entry>
  {{/items}}
</feed>
]]

local function render_feed(context_table)
  return lustache:render(atom_template_string, context_table)
end

local function to_atom_entry_from_doc(doc, root_url_string)
  local title = doc.title
  local contents = doc.contents
  local author = doc.author
  local guid = doc.relative_filepath
  local summary = doc.summary or "" -- optional short description

  local pub_time = derive_date(doc)
  local updated = to_iso8601(pub_time)

  local url = root_url_string:gsub("/$", "") .. "/" .. doc.relative_filepath:gsub("^/", "")
  local pretty_url = url:gsub("/index%.html$", "/")

  -- generate tag URI host/date part
  local tag_host = root_url_string:gsub("^https?://", ""):gsub("/$", "")
  local tag_date = os.date("!%Y-%m-%d", pub_time)

  return {
    title = title,
    url = pretty_url,
    contents = contents,
    summary = summary,
    updated = updated,
    author = author,
    guid = guid,
    tag_host = tag_host,
    tag_date = tag_date
  }
end

local function generate_atom_2(relative_filepath, site_url, site_title, site_description, author_name, author_email)
  -- this is vibe coded version, which doesn't work at all
  local function to_atom_entry(doc)
    return to_atom_entry_from_doc(doc, site_url)
  end

  local take_20_atom_entries = comp(take(20), map(to_atom_entry))

  return function(iter, ...)
    local items = into(take_20_atom_entries, iter, ...)

    local feed_url = site_url .. "/" .. relative_filepath
    local feed_updated
    if #items > 0 then
      feed_updated = items[1].updated
    else
      feed_updated = to_iso8601(os.time())
    end

    local contents = render_feed({
      site_url = site_url,
      site_title = site_title,
      site_description = site_description,
      feed_url = feed_url,
      feed_updated = feed_updated,
      author_name = author_name or "Unknown",
      author_email = author_email,
      items = items
    })

    return wrap_in_iter({
      date = feed_updated,
      contents = contents,
      relative_filepath = relative_filepath
    })
  end
end

local function to_rss_item_from_doc(doc, root_url_string)
  local title = doc.title
  local contents = doc.contents
  local author = doc.author

  -- Reformat doc date as RFC 1123, per RSS spec
  -- http://tools.ietf.org/html/rfc1123.html
  local pubdate = 
    reformat_yyyy_mm_dd(derive_date(doc), "!%a, %d %b %Y %H:%M:%S GMT")
  print("pubdate in item", pubdate)

  -- Create absolute url from root URL and relative path.
  local url = root_url_string:gsub("/$", "") .. "/" .. doc.relative_filepath:gsub("^/", "")
  local pretty_url = url:gsub("/index%.html$", "/")
  local guid = pretty_url -- doc.relative_filepath

  -- The RSS template doesn't really change, so no need to get fancy.
  -- Return just the properties we need for the RSS template.
  return {
    title = title,
    url = pretty_url,
    contents = contents,
    pubdate = pubdate,
    author = author,
    guid = guid
  }
end

-- local function generate_rss(items, relative_filepath, site_url, site_title, site_description, count)
local function generate_atom(items, relative_filepath, site_url, site_title, site_description, count, author_name, author_email)
  local newitems = {}
  -- for _, item in ipairs(items) do
  local count = count or #items
  for i = 1, #items do
    if i <= count then
      local item = items[i]
      table.insert(newitems, to_rss_item_from_doc(item, site_url))
    end
  end
  local feed_updated
  if #items > 0 then
    feed_updated = newitems[1].pubdate
  else
    feed_updated = to_iso8601(os.time())
  end
  print("Feed updated:", feed_updated)
  local feed_url = site_url .. "/" .. relative_filepath
  local context_table = {
    site_title = site_title,
    site_description = site_description,
    site_url = site_url,
    feed_url = feed_url,
    feed_updated = feed_updated,
    author_name = author_name or "Unknown",
    author_email = author_email or "Unknown",
    items = newitems
  }
  return render_feed(context_table)
end

exports.generate_atom = generate_atom
return exports
