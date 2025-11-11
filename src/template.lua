local h5tk = require "h5tk"
local os = require "os"
local date = require "date"

local template = {}

local h = h5tk.init(true)
local html, head, body, title, link, article = h.html, h.head, h.body, h.title, h.link, h.article


local function map(func, tbl)
  local newtbl = {}
  for i,v in pairs(tbl) do
    newtbl[i] = func(v)
  end
  return newtbl
end

local function datetime(time, extraattributes, minutes)
  local d = date(time)
  local extraattributes = (extraattributes and extraattributes .. " ") or ""
  local format = minutes and "%Y-%m-%d %H:%M" or "%Y-%m-%d"
  local timestamp = d:fmt(format)
  return "<time ".. extraattributes .. "datetime='" .. timestamp .. "'>" .. timestamp .. "</time>"
end



local function human_date(time)
  local d = date(time)
  -- format as month-name day, year
  return d:fmt("%B %d, %Y"):gsub(" 0", " ") -- days smaller than 10 contain leading zero, delete it
end

local function archive_item(item)
  return h.p{os.date( "%Y-%m-%d", item.time ), h.a {href=item.relative_filepath, item.title}}
end

local function styles(s)
  local s = s or {}
  local t = {}
  for _, style in ipairs(s) do
    table.insert(t, link {rel="stylesheet", type="text/css", href=style})
  end
  return t
end

local function metaifexitst(key, value, name)
  local property = name and "name" or "property"
  if value then return h.meta{[property] = key, content=value } end
end

local function dublincore(field, value)
  return h.meta {property="dc:"..field, content=value}
end

local function dublincoreterms(field, value)
  return h.meta {name="DCTERMS."..field, content=value}
end

local function opengraph(property, content)
  return h.meta {property="og:" .. property, content=content}
end

local function ogarticle(property, content)
  return h.meta {property="article:" .. property, content=content}
end


function root(doc)
  local published_date = os.date("%Y-%m-%d",doc.time)
  local contenttype = doc.contenttype or "website"
  local url = doc.site_url .. "/" .. doc.relative_filepath
  local menu_separator = ""
  return "<!DOCTYPE html>\n" .. (h.emit(
  html { lang=doc.language, 
    head {prefix="og: http://ogp.me/ns# article: http://ogp.me/ns/article",
      h.meta {charset="utf-8"},
      h.meta {name="viewport", content="width=device-width, initial-scale=1"},
      h.meta {["http-equiv"]="Content-Security-Policy", content="default-src 'self'"},
      h.meta {name="google-site-verification", content="EsWY8xJLGY7SwK9eqJkeqjjGccgwDUqIsEcG2J_ITmE"},

      -- opengraph("type", contenttype),
      -- RDFa should support the following syntax
      -- see https://webmasters.stackexchange.com/a/106283
      h.meta{property="dc:title og:title", content=doc.title},
      h.meta{property="dc:source og:sitename", content=doc.site_title},
      h.meta{property="dc:date article:published", content=published_date},
      h.meta{property="dc:identifier dcterm:URI og:url", content=url},
      h.meta{property="dc:type og:type", content=contenttype},
      -- opengraph("title", doc.title),
      opengraph("url", url),
      ogarticle("author", doc.author_profile),
      -- ogarticle("published", published_date),
      -- opengraph("sitename", doc.site_title),
      -- twitter
      h.link{rel="me",  href="https://twitter.com/michalh21"},
      h.link{rel="me",  href="mailto:michal.h21@gmail.com"},
      h.link{ rel="authorization_endpoint", href="https://indieauth.com/auth"},
       h.link{ rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png" },
       h.link{ rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png" },
       h.link{ rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png" },
       h.link{ rel="manifest", href="/site.webmanifest" },

      h.meta{name="twitter:creator", content="@michalh21"},
      -- atom feeds
      h.link{rel="alternate", type="application/atom+xml", title="Main feed", href="/" .. doc.feed},
      h.link{rel="alternate", type="application/atom+xml", title="Category feed", href="/" .. doc.category_feed},
      -- define dublin core schemas
      -- not necessary anymore
      -- h.link{rel="schema.DC", href="http://purl.org/dc/elements/1.1/"},
      -- h.link{rel="schema.DCTERMS", href="http://purl.org/dc/terms/"},
      dublincore("creator", doc.author),
      dublincore("language", doc.language),
      dublincore("title", doc.title),
      -- dublincore("source", doc.site_title),
      -- dublincore("date", published_date),
      dublincore("format", "text/html"),
      -- dublincore("type", contenttype),
      -- dublincore("identifier", url),
      dublincore("subject", doc.category),
      title { doc.title .. " – ".. doc.site_title },
      (styles(doc.styles)),
    },
    body {
      h.header{class="site-header",
        h.h1{id="home", h.a{href="/", h.img{class="logo", src="/kodymirus.svg", alt=""}, doc.site_title}},
        h.nav{
        role="navigation",["aria-label"]="Main navigation", h.ul{
        map(function(menuitem)
          -- local x = h.emit(h.span{menu_separator, h.a{href=menuitem.href, menuitem.title}})
          -- menu_separator = " | "
          local x = h.emit(h.li{h.a{href=menuitem.href, menuitem.title}})
          -- remove newlines and spurious spaces from menu
          x = x:gsub("%s+", " "):gsub("> ", ">"):gsub(" <" ,"<")
          return x
        end,doc.menu)
      }},
      },
      h.main{doc.contents},
      h.footer{h.p{"© 2025 <a rel='me' class='h-card' href='https://github.com/michal-h21'>Michal Hoftich</a>"}}
    }
  }))
end


function template.page(doc)
  doc.contenttype = "blogposting"
  doc.contents = article {
    class="h-entry",
    itemscope="",
    itemtype="https://schema.org/Article",
    h.div{
      class="e-content",
      itemprop="articleBody",
      doc.contents
    }
  }
  return root(doc)
end



function template.note_archive(doc)
  print("Generating post: ",  doc.title, doc.date, doc.time)
  doc.contents = h.section {class="note-archive",
    h.h2{doc.title},
    h.nav {
      class="pagination", ["aria-label"] = "Blog paging navigation",
      map(function(item)
        return h.article{
          class="h-entry", 
          (item.title and h.a {href=item.relative_filepath, item.title}),
          item.contents,
          h.p{class="permalink", h.a {["aria-label"]="Permalink to the note", class="permalink-link", href=item.relative_filepath,datetime(item.time, "class='dt-published'",  true),  "🔗"}},
        }
      end, doc.list),
      (doc.prev_page_path and h.a {href="/" .. (doc.prev_page_path or "#"), rel="prev", "&lt; Previous"}),
      (doc.next_page_path and h.a {href="/" .. (doc.next_page_path or "#"), rel="next", "Next &gt;"}),
    }
  }

  return root(doc)
end

function template.post(doc)
  doc.contenttype = "blogposting"
  doc.contents = article {
    class="h-entry",
    itemscope="",
    itemtype="https://schema.org/Article",
    h.header{
      h.h2 {class="p-name", itemprop="name", doc.title},
      h.p { class="publish-info",
        "Published by ", h.a{itemprop="author",href=doc.about_page,class="p-author h-card", doc.author}, 
        -- h5tk doesn't know the <time> element, so it is necessary to use it in string
        ' on <time itemprop="datePublished" class="dt-published" datetime="' .. doc.date ..'">'..human_date( doc.time) ..'</time>', 
        "in " , h.a{itemprop="about", href="/category-archive.html#" .. doc.category, doc.category}
      },
    },
    h.section{class="abstract p-summary", itemprop="abstract", role="doc-abstract", doc.abstract},
    h.div{
      class="e-content",
      itemprop="articleBody",
      doc.contents
    }
  }
  return root(doc)
end

function template.note_post(doc)
  doc.contenttype = "blogposting"
  doc.contents = article {
    class="h-entry",
    itemscope="",
    itemtype="https://schema.org/Article",
    h.header{
      h.h2 {class="p-name", itemprop="name", doc.title},
      h.p {class="publish-info",
        "Published by ", h.a{itemprop="author",href=doc.about_page,class="p-author h-card", doc.author}, 
        -- h5tk doesn't know the <time> element, so it is necessary to use it in string
        ' on <time itemprop="datePublished" class="dt-published" datetime="' .. doc.date ..'">'..human_date( doc.time) ..'</time>'
      },
    },
    -- h.section{class="abstract p-summary", itemprop="abstract", role="doc-abstract", doc.abstract},
    h.div{
      class="e-content",
      itemprop="articleBody",
      doc.contents
    }
  }
  return root(doc)
end


function template.index(doc)
  doc.contents = article {
    -- h.h1{doc.title},
    map(function(v)
      return article {
        h.header{
          h.h2{ h.a {href=v.relative_filepath, v.title }},
          h.p{h.time{datetime=os.date( "%Y-%m-%d", v.time ),os.date( "%Y-%m-%d", v.time )}}
        },
        v.abstract,
        h.p {h.a {href=v.relative_filepath, "More"}}
      }
    end, doc.items),
    h.p{h.a{href="archive.html", "Archive"}}
  }
  return root(doc)
end

local function print_archive_items(doc)
  return h.section{
    class="h-feed",
    h.h2{id=doc.name, doc.name, h.a{href=doc.feed, h.img{src="rss.svg"}}},
    map(function(item)
      return h.div{
        class="h-entry",
        h.p{os.date( "%Y-%m-%d", item.time ), h.a {href=item.relative_filepath, item.title}}
      }
    end, doc.items)
  }
end
        


function template.archive(doc)
  doc.name="Archive"
  doc.feed= doc.feed or "feed.xml"
  doc.contents = {
    -- h.h1{doc.title},
    h.aside{h.p{h.a{href="category-archive.html", "Category archive"}}},
    print_archive_items(doc)
  }
  return root(doc)
end

function template.categoryarchive(doc)
  -- save category feeds
  map(function(c) 
    c.feed = c.name .. ".xml" 
  end, doc.categories)
  doc.contents = {
    h.h2 {doc.title},
    h.details{
      h.summary {"Table of contents"},
      h.nav{
        map(function(category)
          return h.div {h.a{href="#" .. category.name, category.name}}
        end, doc.categories)
      }
    },
    map(print_archive_items
    ,doc.categories)
  }
  return root(doc)
 
end


return template
