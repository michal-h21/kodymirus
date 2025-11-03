test_path = test/posts
.PHONY: test



test:
	rm -rf $(test_path)
	mkdir -p $(test_path)
	lua test/make_test_posts.lua
	lua src/blog.lua $(test_path) test/pages test/notes
	cp -a test/static/. www/

