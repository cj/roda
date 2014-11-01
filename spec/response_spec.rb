require File.expand_path("spec_helper", File.dirname(__FILE__))

describe "cookie handling" do
  it "should set cookies on response" do
    app do |r|
      response.set_cookie("foo", "bar")
      response.set_cookie("bar", "baz")
      "Hello"
    end

    header('Set-Cookie').should == "foo=bar\nbar=baz"
    body.should == 'Hello'
  end

  it "should delete cookies on response" do
    app do |r|
      response.set_cookie("foo", "bar")
      response.delete_cookie("foo")
      "Hello"
    end

    header('Set-Cookie').should =~ /foo=; (max-age=0; )?expires=Thu, 01[ -]Jan[ -]1970 00:00:00 (-0000|GMT)/
    body.should == 'Hello'
  end
end

describe "response #[] and #[]=" do
  it "should get/set headers" do
    app do |r|
      response['foo'] = 'bar'
      response['foo'] + response.headers['foo']
    end

    header('foo').should == "bar"
    body.should == 'barbar'
  end
end

describe "response #write" do
  it "should add to body" do
    app do |r|
      response.write 'a'
      response.write 'b'
    end

    body.should == 'ab'
  end
end

describe "response #finish" do
  it "should set status to 404 if body has not been written to" do
    app do |r|
      s, h, b = response.finish
      "#{s}#{h['Content-Type']}#{b.length}"
    end

    body.should == '404text/html0'
  end

  it "should set status to 200 if body has been written to" do
    app do |r|
      response.write 'a'
      s, h, b = response.finish
      response.write "#{s}#{h['Content-Type']}#{b.length}"
    end

    body.should == 'a200text/html1'
  end

  it "should set Content-Length header" do
    app do |r|
      response.write 'a'
      response['Content-Length'].should == nil
      throw :halt, response.finish
    end

    header('Content-Length').should == '1'
  end

  it "should not overwrite existing status" do
    app do |r|
      response.status = 500
      s, h, b = response.finish
      "#{s}#{h['Content-Type']}#{b.length}"
    end

    body.should == '500text/html0'
  end
end

describe "response #finish_with_body" do
  it "should use given body" do
    app do |r|
      throw :halt, response.finish_with_body(['123'])
    end

    body.should == '123'
  end

  it "should set status to 200 if status has not been set" do
    app do |r|
      throw :halt, response.finish_with_body([])
    end

    status.should == 200
  end

  it "should not set Content-Length header" do
    app do |r|
      response.write 'a'
      response['Content-Length'].should == nil
      throw :halt, response.finish_with_body(['123'])
    end

    header('Content-Length').should == nil
  end

  it "should not overwrite existing status" do
    app do |r|
      response.status = 500
      throw :halt, response.finish_with_body(['123'])
    end

    status.should == 500
  end
end

describe "response #redirect" do
  it "should set location and status" do
    app do |r|
      r.on 'a' do
        response.redirect '/foo', 303
      end
      r.on do
        response.redirect '/bar'
      end
    end

    status('/a').should == 303
    status.should == 302
    header('Location', '/a').should == '/foo'
    header('Location').should == '/bar'
  end
end

describe "response #empty?" do
  it "should return whether the body is empty" do
    app do |r|
      r.on 'a' do
        response['foo'] = response.empty?.to_s
      end
      r.on do
        response.write 'a'
        response['foo'] = response.empty?.to_s
      end
    end

    header('foo', '/a').should == 'true'
    header('foo').should == 'false'
  end
end

describe "response #inspect" do
  it "should return information about response" do
    app(:bare) do
      def self.inspect
        'Foo'
      end

      route do |r|
        response.status = 200
        response.inspect
      end
    end

    body.should == '#<Foo::RodaResponse 200 {"Content-Type"=>"text/html"} []>'
  end
end
