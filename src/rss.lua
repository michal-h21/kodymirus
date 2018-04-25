-- reuse code from lettersmith
-- generate RSS from a table, not from docs iterator

local lustache = require("lustache")

local docs = require("lettersmith.docs_utils")
local derive_date = docs.derive_date
local reformat_yyyy_mm_dd = docs.reformat_yyyy_mm_dd

local rss_template_string = [[
<rss version="2.0"  xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
  <title>{{site_title}}</title>
  <link>{{{site_url}}}</link>
  <atom:link href="{{{feed_url}}}" rel="self" type="application/rss+xml" />
  <description>{{site_description}}</description>
  <generator>Lettersmith</generator>
  {{#items}}
  <item>
    {{#title}}
    <title>{{title}}</title>
    {{/title}}
    <link>{{{url}}}</link>
    <description>{{contents}}</description>
    <pubDate>{{pubdate}}</pubDate>
    <guid isPermaLink="false">{{guid}}</guid>
    {{#author}}
    <author>{{author}}</author>
    {{/author}}
  </item>
  {{/items}}
</channel>
</rss>
]]

local function render_feed(context_table)
  -- Given table with feed data, render feed string.
  -- Returns rendered string.
  return lustache:render(rss_template_string, context_table)
end

local function to_rss_item_from_doc(doc, root_url_string)
  local title = doc.title
  local contents = doc.contents
  local author = doc.author
  local guid = doc.relative_filepath

  -- Reformat doc date as RFC 1123, per RSS spec
  -- http://tools.ietf.org/html/rfc1123.html
  local pubdate =
    reformat_yyyy_mm_dd(derive_date(doc), "!%a, %d %b %Y %H:%M:%S GMT")

  -- Create absolute url from root URL and relative path.
  local url = root_url_string:gsub("/$", "") .. "/" .. doc.relative_filepath:gsub("^/", "")
  local pretty_url = url:gsub("/index%.html$", "/")

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


local function generate_rss(items, relative_filepath, site_url, site_title, site_description)
  local newitems = {}
  for _, item in ipairs(items) do
    table.insert(newitems, to_rss_item_from_doc(item, site_url))
  end
  local feed_url = site_url .. "/" .. relative_filepath
  local context_table = {
    site_title = site_title,
    site_description = site_description,
    site_url = site_url,
    feed_url = feed_url,
    items = newitems
  }
  return render_feed(context_table)
end
  
return {
  rss_table = generate_rss
}

