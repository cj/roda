require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "symbol_matchers plugin" do 
  it "allows symbol specific regexps" do
    app(:bare) do
      plugin :symbol_matchers
      symbol_matcher(:f, /(f+)/)

      route do |r|
        r.is :d do |d|
          "d#{d}"
        end

        r.is "foo:optd" do |o|
          "foo#{o.inspect}"
        end

        r.is "bar:opt" do |o|
          "bar#{o.inspect}"
        end

        r.is "format:format" do |f|
          "format#{f.inspect}"
        end

        r.is "thing/:thing" do |d|
          "thing#{d}"
        end

        r.is :f do |f|
          "f#{f}"
        end

        r.is 'q:rest' do |rest|
          "rest#{rest}"
        end

        r.is :w do |w|
          "w#{w}"
        end

        r.is ':d/:w/:f' do |d, w, f|
          "dwf#{d}#{w}#{f}"
        end
      end
    end

    status.should == 404
    body("/1").should == 'd1'
    body("/11232135").should == 'd11232135'
    body("/a").should == 'wa'
    body("/1az0").should == 'w1az0'
    body("/f").should == 'ff'
    body("/foo").should == 'foonil'
    body("/foo/123").should == 'foo"123"'
    status("/foo/bar").should == 404
    status("/foo/123/a").should == 404
    body("/bar").should == 'barnil'
    body("/bar/foo").should == 'bar"foo"'
    status("/bar/foo/baz").should == 404
    body("/format").should == 'formatnil'
    body("/format.json").should == 'format"json"'
    status("/format.").should == 404
    body("/ffffffffffffffff").should == 'fffffffffffffffff'
    status("/-").should == 404
    body("/1/1a/f").should == 'dwf11af'
    body("/12/1azy/fffff").should == 'dwf121azyfffff'
    status("/1/f/a").should == 404
    body("/qa/b/c/d//f/g").should == 'resta/b/c/d//f/g'
    body('/q').should == 'rest'
    body('/thing/q').should == 'thingq'
  end
end
