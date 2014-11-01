require File.expand_path("spec_helper", File.dirname(__FILE__))

describe "request.full_path_info" do
  it "should return the script name and path_info as a string" do
    app do |r|
      r.on "foo" do
        "#{r.full_path_info}:#{r.script_name}:#{r.path_info}"
      end
    end

    body("/foo/bar").should ==  "/foo/bar:/foo:/bar"
  end
end

describe "request.halt" do
  it "should return rack response as argument given it as argument" do
    app do |r|
      r.halt [200, {}, ['foo']]
    end

    body.should ==  "foo"
  end

  it "should use current response if no argument is given" do
    app do |r|
      response.write('foo')
      r.halt
    end

    body.should ==  "foo"
  end
end

describe "request.scope" do
  it "should return roda instance" do
    app(:bare) do
      attr_accessor :b

      route do |r|
        self.b = 'a'
        request.scope.b
      end
    end

    body.should ==  "a"
  end
end

describe "request.inspect" do
  it "should return information about request" do
    app(:bare) do
      def self.inspect
        'Foo'
      end

      route do |r|
        request.inspect
      end
    end

    body('/a/b').should ==  "#<Foo::RodaRequest GET /a/b>"
    body('REQUEST_METHOD'=>'POST').should ==  "#<Foo::RodaRequest POST />"
  end
end

describe "TERM.inspect" do
  it "should return TERM" do
    app do |r|
      r.class::TERM.inspect
    end

    body.should ==  "TERM"
  end
end
