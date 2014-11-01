require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "error_email plugin" do 
  def app(opts={})
    @emails = emails = [] unless defined?(@emails)
    @app ||= super(:bare) do
      plugin :error_email, {:to=>'t', :from=>'f', :emailer=>lambda{|h| emails << h}}.merge(opts)

      route do |r|
        raise ArgumentError rescue error_email($!)
        'e'
      end
    end
  end

  def email
    @emails.last
  end

  it "adds error_email method for emailing exceptions" do
    app
    body('rack.input'=>StringIO.new, 'QUERY_STRING'=>'b=c', 'rack.session'=>{'d'=>'e'}).should == 'e'
    email[:to].should == 't'
    email[:from].should == 'f'
    email[:host].should == 'localhost'
    email[:message].should =~ /^Subject: ArgumentError/
    email[:message].should =~ /^Backtrace:$.+^ENV:$.+^"rack\.input" => .+^Params:$\s+^"b" => "c"$\s+^Session:$\s+^"d" => "e"$/m
  end

  it "uses :host option" do
    app(:host=>'foo.bar.com')
    body('rack.input'=>StringIO.new).should == 'e'
    email[:host].should == 'foo.bar.com'
  end

  it "handles error messages with new lines" do
    app.route do |r|
      raise "foo\nbar\nbaz" rescue error_email($!)
      'e'
    end
    body('rack.input'=>StringIO.new).should == 'e'
    email[:message].should =~ %r{From: f\r\nSubject: RuntimeError: foo\r\n bar\r\n baz\r\nTo: t\r\n\r\n}
  end

  it "adds :prefix option to subject line" do
    app(:prefix=>'TEST ')
    body('rack.input'=>StringIO.new).should == 'e'
    email[:message].should =~ /^Subject: TEST ArgumentError/
  end

  it "uses :headers option for additional headers" do
    app(:headers=>{'Foo'=>'Bar', 'Baz'=>'Quux'})
    body('rack.input'=>StringIO.new).should == 'e'
    email[:message].should =~ /^Foo: Bar/
    email[:message].should =~ /^Baz: Quux/
  end

  it "requires the :to and :from options" do
    proc{app :from=>nil}.should raise_error(Roda::RodaError)
    proc{app :to=>nil}.should raise_error(Roda::RodaError)
  end

  it "works correctly in subclasses" do
    @app = Class.new(app)
    @app.route do |r|
      raise ArgumentError rescue error_email($!)
      'e'
    end
    body('rack.input'=>StringIO.new).should == 'e'
    email[:to].should == 't'
    email[:from].should == 'f'
    email[:host].should == 'localhost'
    email[:message].should =~ /^Subject: ArgumentError/
    email[:message].should =~ /Backtrace.*ENV/m
  end
end
