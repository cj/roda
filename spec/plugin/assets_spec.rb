require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

begin
  for lib in %w'tilt sass coffee-script'
    require lib
  end
  run_tests = true
rescue LoadError
  warn "#{lib} not installed, skipping assets plugin test"
rescue
  # ExecJS::RuntimeUnavailable may or may not be defined, so can't just do:
  #   rescue ExecJS::RuntimeUnavailable'
  if $!.class.name == 'ExecJS::RuntimeUnavailable'
    warn "#{$!.to_s}: skipping assets plugin tests"
  else
    raise
  end
end

if run_tests
  js_file = 'spec/assets/js/head/app.coffee'
  css_file = 'spec/assets/css/no_access.css'
  js_mtime = File.mtime(js_file)
  js_atime = File.atime(js_file)
  css_mtime = File.mtime(css_file)
  css_atime = File.atime(css_file)
  describe 'assets plugin' do
    before do
      app(:bare) do
        plugin :assets,
          :css => ['app.scss', 'raw.css'],
          :js => { :head => ['app.coffee'] },
          :path => 'spec/assets',
          :public => 'spec'

        route do |r|
          r.assets

          r.is 'test' do
            "#{assets(:css)}\n#{assets([:js, :head])}"
          end
        end
      end
    end
    after do
      File.utime(js_atime, js_mtime, js_file)
      File.utime(css_atime, css_mtime, css_file)
    end

    it 'assets_opts should use correct paths given options' do
      keys = [:js_path, :css_path, :compiled_js_path, :compiled_css_path, :js_prefix, :css_prefix, :compiled_js_prefix, :compiled_css_prefix]
      app.assets_opts.values_at(*keys).should == %w"spec/assets/js/ spec/assets/css/ spec/assets/js/app spec/assets/css/app assets/js/ assets/css/ assets/js/app assets/css/app"

      app.plugin :assets, :path=>'bar/', :public=>'foo/', :prefix=>'as/', :js_dir=>'j/', :css_dir=>'c/', :compiled_name=>'a'
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/as/j/a foo/as/c/a as/j/ as/c/ as/j/a as/c/a"

      app.plugin :assets, :path=>'bar', :public=>'foo', :prefix=>'as', :js_dir=>'j', :css_dir=>'c', :compiled_name=>'a'
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/as/j/a foo/as/c/a as/j/ as/c/ as/j/a as/c/a"

      app.plugin :assets, :compiled_js_dir=>'cj', :compiled_css_dir=>'cs', :compiled_path=>'cp'
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/cp/cj/a foo/cp/cs/a as/j/ as/c/ as/cj/a as/cs/a"

      app.plugin :assets
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/cp/cj/a foo/cp/cs/a as/j/ as/c/ as/cj/a as/cs/a"

      app.plugin :assets
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/cp/cj/a foo/cp/cs/a as/j/ as/c/ as/cj/a as/cs/a"

      app.plugin :assets, :compiled_js_dir=>'', :compiled_css_dir=>nil
      app.assets_opts.values_at(*keys).should == %w"bar/j/ bar/c/ foo/cp/a foo/cp/a as/j/ as/c/ as/a as/a"

      app.plugin :assets, :js_dir=>'', :css_dir=>nil
      app.assets_opts.values_at(*keys).should == %w"bar/ bar/ foo/cp/a foo/cp/a as/ as/ as/a as/a"

      app.plugin :assets, :public=>''
      app.assets_opts.values_at(*keys).should == %w"bar/ bar/ cp/a cp/a as/ as/ as/a as/a"

      app.plugin :assets, :path=>'', :compiled_path=>nil
      app.assets_opts.values_at(*keys).should == ['', '', 'a', 'a', 'as/', 'as/', 'as/a', 'as/a']

      app.plugin :assets, :prefix=>''
      app.assets_opts.values_at(*keys).should == ['', '', 'a', 'a', '', '', 'a', 'a']

      app.plugin :assets, :compiled_name=>nil
      app.assets_opts.values_at(*keys).should == ['', '', '', '', '', '', '', '']
    end

    it 'assets_opts should use headers and dependencies given options' do
      keys = [:css_headers, :js_headers, :dependencies]
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"text/css; charset=UTF-8"}, {'Content-Type'=>"application/javascript; charset=UTF-8"}, {}]

      app.plugin :assets, :headers=>{'A'=>'B'}, :dependencies=>{'a'=>'b'}
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"text/css; charset=UTF-8", 'A'=>'B'}, {'Content-Type'=>"application/javascript; charset=UTF-8", 'A'=>'B'}, {'a'=>'b'}]

      app.plugin :assets, :css_headers=>{'C'=>'D'}, :js_headers=>{'E'=>'F'}, :dependencies=>{'c'=>'d'}
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"text/css; charset=UTF-8", 'A'=>'B', 'C'=>'D'}, {'Content-Type'=>"application/javascript; charset=UTF-8", 'A'=>'B', 'E'=>'F'}, {'a'=>'b', 'c'=>'d'}]

      app.plugin :assets
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"text/css; charset=UTF-8", 'A'=>'B', 'C'=>'D'}, {'Content-Type'=>"application/javascript; charset=UTF-8", 'A'=>'B', 'E'=>'F'}, {'a'=>'b', 'c'=>'d'}]

      app.plugin :assets
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"text/css; charset=UTF-8", 'A'=>'B', 'C'=>'D'}, {'Content-Type'=>"application/javascript; charset=UTF-8", 'A'=>'B', 'E'=>'F'}, {'a'=>'b', 'c'=>'d'}]

      app.plugin :assets, :headers=>{'Content-Type'=>'C', 'E'=>'G'}
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"C", 'A'=>'B', 'C'=>'D', 'E'=>'G'}, {'Content-Type'=>"C", 'A'=>'B', 'E'=>'F'}, {'a'=>'b', 'c'=>'d'}]

      app.plugin :assets, :css_headers=>{'A'=>'B1'}, :js_headers=>{'E'=>'F1'}, :dependencies=>{'c'=>'d1'}
      app.assets_opts.values_at(*keys).should == [{'Content-Type'=>"C", 'A'=>'B1', 'C'=>'D', 'E'=>'G'}, {'Content-Type'=>"C", 'A'=>'B', 'E'=>'F1'}, {'a'=>'b', 'c'=>'d1'}]
    end

    it 'should handle rendering assets, linking to them, and accepting requests for them when not compiling' do
      html = body('/test')
      html.scan(/<link/).length.should == 2
      html =~ %r{href="(/assets/css/app\.scss)"}
      css = body($1)
      html =~ %r{href="(/assets/css/raw\.css)"}
      css2 = body($1)
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/head/app\.coffee)"}
      js = body($1)
      css.should =~ /color: red;/
      css2.should =~ /color: blue;/
      js.should include('console.log')
    end

    it 'should handle rendering assets, linking to them, and accepting requests for them when not compiling, with different options' do
      app.plugin :assets, :path=>'spec/', :js_dir=>'assets/js', :css_dir=>'assets/css', :prefix=>'a'
      html = body('/test')
      html.scan(/<link/).length.should == 2
      html =~ %r{href="(/a/assets/css/app\.scss)"}
      css = body($1)
      html =~ %r{href="(/a/assets/css/raw\.css)"}
      css2 = body($1)
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/a/assets/js/head/app\.coffee)"}
      js = body($1)
      css.should =~ /color: red;/
      css2.should =~ /color: blue;/
      js.should include('console.log')
    end

    it 'should handle compiling assets, linking to them, and accepting requests for them' do
      app.compile_assets
      html = body('/test')
      html.scan(/<link/).length.should == 1
      html =~ %r{href="(/assets/css/app\.[a-f0-9]{40}\.css)"}
      css = body($1)
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      css.should =~ /color: ?red/
      css.should =~ /color: ?blue/
      js.should include('console.log')
    end

    it 'should handle compiling assets, linking to them, and accepting requests for them, with different options' do
      app.plugin :assets, :compiled_path=>nil, :js_dir=>'assets/js', :css_dir=>'assets/css', :prefix=>'a', :public=>'spec', :path=>'spec' 
      app.compile_assets
      html = body('/test')
      html.scan(/<link/).length.should == 1
      html =~ %r{href="(/a/assets/css/app\.[a-f0-9]{40}\.css)"}
      css = body($1)
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/a/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      css.should =~ /color: ?red/
      css.should =~ /color: ?blue/
      js.should include('console.log')
    end

    it 'should handle compiling only css assets' do
      app.compile_assets(:css)
      html = body('/test')
      html.scan(/<link/).length.should == 1
      html =~ %r{href="(/assets/css/app\.[a-f0-9]{40}\.css)"}
      css = body($1)
      html.scan(/<script/).length.should == 0
      css.should =~ /color: ?red/
      css.should =~ /color: ?blue/
    end

    it 'should handle compiling only js assets' do
      app.compile_assets(:js)
      html = body('/test')
      html.scan(/<link/).length.should == 0
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      js.should include('console.log')
    end

    it 'should handle compiling asset subfolders' do
      app.compile_assets([:js, :head])
      html = body('/test')
      html.scan(/<link/).length.should == 0
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      js.should include('console.log')
    end

    it 'should handle compiling assets when only a single asset type is present' do
      app.plugin :assets, :css=>nil
      app.compile_assets
      html = body('/test')
      html.scan(/<link/).length.should == 0
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      js.should include('console.log')
    end

    it 'should handle compiling assets when an empty array is used' do
      app.plugin :assets, :css=>[]
      app.compile_assets
      html = body('/test')
      html.scan(/<link/).length.should == 0
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/app\.head\.[a-f0-9]{40}\.js)"}
      js = body($1)
      js.should include('console.log')
    end

    it '#assets should include attributes given' do
      app.new.assets([:js, :head], 'a'=>'b').should == '<script type="text/javascript" a="b" src="/assets/js/head/app.coffee"></script>'
    end

    it '#assets should escape attribute values given' do
      app.new.assets([:js, :head], 'a'=>'b"e').should == '<script type="text/javascript" a="b&quot;e" src="/assets/js/head/app.coffee"></script>'
    end

    it 'requests for assets should return 304 if the asset has not been modified' do
      loc = '/assets/js/head/app.coffee'
      lm = header('Last-Modified', loc)
      status(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == 304
      body(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == ''
    end

    it 'requests for assets should not return 304 if the asset has been modified' do
      loc = '/assets/js/head/app.coffee'
      lm = header('Last-Modified', loc)
      File.utime(js_atime, js_mtime+1, js_file)
      status(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == 200
      body(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should include('console.log')
    end

    it 'requests for assets should return 304 if the dependency of an asset has not been modified' do
      app.plugin :assets, :dependencies=>{js_file=>css_file}
      loc = '/assets/js/head/app.coffee'
      lm = header('Last-Modified', loc)
      status(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == 304
      body(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == ''
    end

    it 'requests for assets should return 200 if the dependency of an asset has been modified' do
      app.plugin :assets, :dependencies=>{js_file=>css_file}
      loc = '/assets/js/head/app.coffee'
      lm = header('Last-Modified', loc)
      File.utime(css_atime, [css_mtime+1, js_mtime+1].max, css_file)
      status(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should == 200
      body(loc, 'HTTP_IF_MODIFIED_SINCE'=>lm).should include('console.log')
    end

    it 'should do a terminal match for assets' do
      status('/assets/css/app.scss/foo').should == 404
    end

    it 'should only allow files that you specify' do
      status('/assets/css/no_access.css').should == 404
    end

    it 'should not add routes for empty asset types' do
      app.plugin :assets, :css=>nil
      a = app::RodaRequest.assets_matchers
      a.length.should == 1
      a.first.length.should == 2
      a.first.first.should == 'js'
      'assets/js/head/app.coffee'.should =~ a.first.last
      'assets/js/head/app2.coffee'.should_not =~ a.first.last
    end

    it 'should not add routes if no asset types' do
      app.plugin :assets, :js=>nil, :css=>nil
      app::RodaRequest.assets_matchers.should == []
    end
  end
end
