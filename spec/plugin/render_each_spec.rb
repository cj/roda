require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "render_each plugin" do 
  it "calls render with each argument, returning joined string with all results" do
    app(:bare) do
      plugin :render_each
      def render(t, opts)
        "r#{t}#{opts[:locals][:foo] if opts[:locals]}#{opts[:bar]}#{opts[:locals][:bar] if opts[:locals]} "
      end 

      route do |r|
        r.root do
          render_each([1,2,3], :foo)
        end

        r.is 'a' do
          render_each([1,2,3], :bar, :local=>:foo, :bar=>4)
        end

        r.is 'b' do
          render_each([1,2,3], :bar, :local=>nil)
        end

        r.is 'c' do
          render_each([1,2,3], :bar, :locals=>{:foo=>4})
        end
      end
    end

    body.should == 'rfoo1 rfoo2 rfoo3 '
    body("/a").should == 'rbar14 rbar24 rbar34 '
    body("/b").should == 'rbar rbar rbar '
    body("/c").should == 'rbar41 rbar42 rbar43 '
  end
end
