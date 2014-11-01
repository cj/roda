require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "multi_route plugin" do 
  before do
    app(:bare) do
      plugin :multi_route

      route("get") do |r|
        r.is "" do
          "get"
        end
        
        r.is "a" do
          "geta"
        end

        "getd"
      end

      route("post") do |r|
        r.is "" do
          "post"
        end
        
        r.is "a" do
          "posta"
        end

        "postd"
      end

      route(:p) do |r|
        r.is do
          'p'
        end
      end

      route do |r|
        r.on 'foo' do
          r.multi_route do
            "foo"
          end

          r.on "p" do
            r.route(:p)
          end
        end

        r.get do
          r.route("get")

          r.is "b" do
            "getb"
          end
        end

        r.post do
          r.route("post")

          r.is "b" do
            "postb"
          end
        end
      end
    end
  end

  it "adds named routing support" do
    body.should == 'get'
    body('REQUEST_METHOD'=>'POST').should == 'post'
    body('/a').should == 'geta'
    body('/a', 'REQUEST_METHOD'=>'POST').should == 'posta'
    body('/b').should == 'getb'
    body('/b', 'REQUEST_METHOD'=>'POST').should == 'postb'
    status('/c').should == 404
    status('/c', 'REQUEST_METHOD'=>'POST').should == 404
  end

  it "uses multi_route to dispatch to any named route" do
    status('/foo').should == 404
    body('/foo/get/').should == 'get'
    body('/foo/get/a').should == 'geta'
    body('/foo/post/').should == 'post'
    body('/foo/post/a').should == 'posta'
    body('/foo/post/b').should == 'foo'
  end

  it "does not have multi_route match non-String named routes" do
    body('/foo/p').should == 'p'
    status('/foo/p/2').should == 404
  end

  it "has multi_route pick up routes newly added" do
    body('/foo/get/').should == 'get'
    status('/foo/delete').should == 404
    app.route('delete'){|r| r.on{'delete'}}
    body('/foo/delete').should == 'delete'
  end

  it "makes multi_route match longest route if multiple routes have the same prefix" do
    app.route("post/a"){|r| r.on{"pa2"}}
    app.route("get/a"){|r| r.on{"ga2"}}
    status('/foo').should == 404
    body('/foo/get/').should == 'get'
    body('/foo/get/a').should == 'ga2'
    body('/foo/post/').should == 'post'
    body('/foo/post/a').should == 'pa2'
    body('/foo/post/b').should == 'foo'
  end

  it "handles loading the plugin multiple times correctly" do
    app.plugin :multi_route
    body.should == 'get'
    body('REQUEST_METHOD'=>'POST').should == 'post'
    body('/a').should == 'geta'
    body('/a', 'REQUEST_METHOD'=>'POST').should == 'posta'
    body('/b').should == 'getb'
    body('/b', 'REQUEST_METHOD'=>'POST').should == 'postb'
    status('/c').should == 404
    status('/c', 'REQUEST_METHOD'=>'POST').should == 404
  end

  it "handles subclassing correctly" do
    @app = Class.new(@app)
    @app.route do |r|
      r.get do
        r.route("post")

        r.is "b" do
          "1b"
        end
      end
      r.post do
        r.route("get")

        r.is "b" do
          "2b"
        end
      end
    end

    body.should == 'post'
    body('REQUEST_METHOD'=>'POST').should == 'get'
    body('/a').should == 'posta'
    body('/a', 'REQUEST_METHOD'=>'POST').should == 'geta'
    body('/b').should == '1b'
    body('/b', 'REQUEST_METHOD'=>'POST').should == '2b'
    status('/c').should == 404
    status('/c', 'REQUEST_METHOD'=>'POST').should == 404
  end

  it "uses the named route return value in multi_route if no block is given" do
    app.route{|r| r.multi_route}
    body('/get').should == 'getd'
    body('/post').should == 'postd'
  end
end

describe "multi_route plugin" do 
  before do
    app(:bare) do
      plugin :multi_route

      route("foo", "foo") do |r|
        "#{@p}ff"
      end

      route("bar", "foo") do |r|
        "#{@p}fb"
      end

      route("foo", "bar") do |r|
        "#{@p}bf"
      end

      route("bar", "bar") do |r|
        "#{@p}bb"
      end
    end
  end

  it "handles namespaces in r.route" do
    app.route("foo") do |r|
      @p = 'f'
      r.on("foo"){r.route("foo", "foo")}
      r.on("bar"){r.route("bar", "foo")}
      @p
    end

    app.route("bar") do |r|
      @p = 'b'
      r.on("foo"){r.route("foo", "bar")}
      r.on("bar"){r.route("bar", "bar")}
      @p
    end

    app.route do |r|
      r.on("foo"){r.route("foo")}
      r.on("bar"){r.route("bar")}
    end

    body('/foo').should == 'f'
    body('/foo/foo').should == 'fff'
    body('/foo/bar').should == 'ffb'
    body('/bar').should == 'b'
    body('/bar/foo').should == 'bbf'
    body('/bar/bar').should == 'bbb'
  end

  it "handles namespaces in r.multi_route" do
    app.route("foo") do |r|
      @p = 'f'
      r.multi_route("foo")
      @p
    end

    app.route("bar") do |r|
      @p = 'b'
      r.multi_route("bar")
      @p
    end

    app.route do |r|
      r.multi_route
    end

    body('/foo').should == 'f'
    body('/foo/foo').should == 'fff'
    body('/foo/bar').should == 'ffb'
    body('/bar').should == 'b'
    body('/bar/foo').should == 'bbf'
    body('/bar/bar').should == 'bbb'
  end
end
