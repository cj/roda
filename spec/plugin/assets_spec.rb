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
          :css => ['app.scss', '../raw.css'],
          :js => { :head => ['app.coffee'] },
          :path => './spec/dummy/assets',
          :compiled_path => './spec/dummy/assets',
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
      app.assets_opts[:path].should == './spec/dummy/assets'
      app.assets_opts[:css].should include('app.scss')
    end

    it 'should serve proper assets when not compiled' do
      body('/assets/css/app.scss.css').should include('color: red')
      body('/assets/js/head/app.coffee.js').should include('console.log')
    end

    it 'should contain proper assets html tags' do
      html = body '/test'
      html.scan(/<link/).length.should == 2
      html.scan(/<script/).length.should == 1
      html.should include('link')
      html.should include('script')
    end

    it 'should handle compiling assets, linking to them, and accept requests for them' do
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
      body('/assets/css/%242E%242E/%242E%242E/no_access.css').should_not include('no access')
    end
  end
end
