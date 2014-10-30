require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

begin
  for lib in %w'tilt tilt/sass tilt/coffee'
    require lib
  end
  run_tests = true
rescue LoadError
  warn "#{lib} not installed, skipping assets plugin test"
rescue
  # ExecJS::RuntimeUnavailable may or may not be defined, so can't use do:
  #   rescue ExecJS::RuntimeUnavailable'
  if $!.class.name == 'ExecJS::RuntimeUnavailable'
    warn "#{$!.to_s}: skipping assets plugin tests"
  else
    raise
  end
end

if run_tests
  describe 'assets plugin' do
    before do
      app(:bare) do
        plugin:assets,
          :css => ['app.scss', 'raw.css'],
          :js => { :head => ['app.coffee'] },
          :path => 'spec/assets',
          :compiled_path => 'spec/assets',
          :headers => {
            "Cache-Control"             => 'public, max-age=2592000, no-transform',
            'Connection'                => 'keep-alive',
            'Age'                       => '25637',
            'Strict-Transport-Security' => 'max-age=31536000',
            'Content-Disposition'       => 'inline'
          }

        route do |r|
          r.assets

          r.is 'test' do
            response.write assets :css
            response.write assets [:js, :head]
          end
        end
      end
    end

    it 'should contain proper configuration' do
      app.assets_opts[:path].should == 'spec/assets'
      app.assets_opts[:css].should include('app.scss')
    end

    it 'should handle rendering assets, linking to them, and accepting requests for them when not compiling' do
      html = body('/test')
      html.scan(/<link/).length.should == 2
      html =~ %r{href="(/assets/css/app.scss.css)"}
      css = body($1)
      html =~ %r{href="(/assets/css/raw.css.css)"}
      css2 = body($1)
      html.scan(/<script/).length.should == 1
      html =~ %r{src="(/assets/js/head/app.coffee.js)"}
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
      css.should =~ /color: red;/
      css.should =~ /color: blue;/
      js.should include('console.log')
    end

    it 'should only allow files in your list' do
      status('/assets/css/no_access.css.css').should == 404
    end
  end
end
