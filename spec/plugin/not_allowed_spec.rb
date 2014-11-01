require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "not_allowed plugin" do 
  it "skips the current block if pass is called" do
    app(:not_allowed) do |r|
      r.get '' do
        'a'
      end

      r.is "c" do
        r.get do
          "cg"
        end

        r.post do
          "cp"
        end

        "c"
      end

      r.on "q" do
        r.is do
          r.get do
            "q"
          end
        end
      end

      r.get do
        r.is 'b' do
          'b'
        end
        r.is(/(d)/) do |s|
          s
        end
        r.get(/(e)/) do |s|
          s
        end
      end
    end

    body.should == 'a'
    status('REQUEST_METHOD'=>'POST').should == 405
    header('Allow', 'REQUEST_METHOD'=>'POST').should == 'GET'

    body('/b').should == 'b'
    status('/b', 'REQUEST_METHOD'=>'POST').should == 404

    body('/d').should == 'd'
    status('/d', 'REQUEST_METHOD'=>'POST').should == 404

    body('/e').should == 'e'
    status('/e', 'REQUEST_METHOD'=>'POST').should == 404

    body('/q').should == 'q'
    status('/q', 'REQUEST_METHOD'=>'POST').should == 405

    body('/c').should == 'cg'
    body('/c').should == 'cg'
    body('/c', 'REQUEST_METHOD'=>'POST').should == 'cp'
    body('/c', 'REQUEST_METHOD'=>'PATCH').should == 'c'
    status('/c', 'REQUEST_METHOD'=>'PATCH').should == 405
    header('Allow', '/c', 'REQUEST_METHOD'=>'PATCH').should == 'GET, POST'
  end
end
