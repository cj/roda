require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe 'response.cache_control' do
  it 'sets the Cache-Control header' do
    app(:caching) do |r|
      response.cache_control :public=>true, :no_cache=>true, :max_age => 60
    end
    header('Cache-Control').split(', ').sort.should == ['max-age=60', 'no-cache', 'public']
  end

  it 'does not add a Cache-Control header if it would be empty' do
    app(:caching) do |r|
      response.cache_control({})
    end
    header('Cache-Control').should == nil
  end
end

describe 'response.expires' do
  it 'sets the Cache-Control and Expires header' do
    app(:caching) do |r|
      response.expires 60, :public=>true, :no_cache=>true
    end
    header('Cache-Control').split(', ').sort.should == ['max-age=60', 'no-cache', 'public']
    ((Time.httpdate(header('Expires')) - Time.now).round - 60).abs.should <= 1
  end

  it 'can be called with only one argument' do
    app(:caching) do |r|
      response.expires 60
    end
    header('Cache-Control').split(', ').sort.should == ['max-age=60']
    ((Time.httpdate(header('Expires')) - Time.now).round - 60).abs.should <= 1
  end
end

describe 'response.finish' do
  it 'removes Content-Type and Content-Length for 304 responses' do
    app(:caching) do |r|
      response.status = 304
    end
    header('Content-Type').should == nil
    header('Content-Length').should == nil
  end

  it 'does not change non-304 responses' do
    app(:caching) do |r|
      response.status = 200
    end
    header('Content-Type').should == 'text/html'
    header('Content-Length').should == '0'
  end
end

describe 'request.last_modified' do
  it 'ignores nil' do
    app(:caching) do |r|
      r.last_modified nil
    end
    header('Last-Modified').should == nil
  end

  it 'does not change a status other than 200' do
    app(:caching) do |r|
      response.status = 201
      r.last_modified Time.now
    end
    status.should == 201
    status('HTTP_IF_MODIFIED_SINCE' => 'Sun, 26 Sep 2030 23:43:52 GMT').should == 201
    status('HTTP_IF_MODIFIED_SINCE' => 'Sun, 26 Sep 2000 23:43:52 GMT').should == 201
  end
end

describe 'request.last_modified' do
  def res(a={})
    s, h, b = req(a)
    h['Last-Modified'].should == @last_modified.httpdate
    [s, b.join]
  end

  before(:all) do
    lm = @last_modified = Time.now
    app(:caching) do |r|
      r.last_modified lm
      'ok'
    end
  end

  it 'just sets Last-Modified if no If-Modified-Since header' do
    res.should == [200, 'ok']
  end

  it 'just sets Last-Modified if bogus If-Modified-Since header' do
    res('HTTP_IF_MODIFIED_SINCE' => 'a really weird date').should == [200, 'ok']
  end

  it 'just sets Last-Modified if modified since If-Modified-Since header' do
    res('HTTP_IF_MODIFIED_SINCE' => (@last_modified - 1).httpdate).should == [200, 'ok']
  end

  it 'sets Last-Modified and returns 304 if modified on If-Modified-Since header' do
    res('HTTP_IF_MODIFIED_SINCE' => @last_modified.httpdate).should == [304, '']
  end

  it 'sets Last-Modified and returns 304 if modified before If-Modified-Since header' do
    res('HTTP_IF_MODIFIED_SINCE' => (@last_modified + 1).httpdate).should == [304, '']
  end

  it 'sets Last-Modified if If-None-Match header present' do
    res('HTTP_IF_NONE_MATCH' => '*', 'HTTP_IF_MODIFIED_SINCE' => (@last_modified + 1).httpdate).should == [200, 'ok']
  end

  it 'sets Last-Modified if modified before If-Unmodified-Since header' do
    res('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified + 1).httpdate).should == [200, 'ok']
  end

  it 'sets Last-Modified if modified on If-Unmodified-Since header' do
    res('HTTP_IF_UNMODIFIED_SINCE' => @last_modified.httpdate).should == [200, 'ok']
  end

  it 'sets Last-Modified and returns 412 if modified after If-Unmodified-Since header' do
    res('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified - 1).httpdate).should == [412, '']
  end
end

describe 'request.etag' do
  before(:all) do
    app(:caching) do |r|
      r.is "" do
        response.status = r.env['status'] if r.env['status']
        etag_opts = {}
        etag_opts[:new_resource] = r.env['new_resource'] if r.env.has_key?('new_resource')
        etag_opts[:weak] = r.env['weak'] if r.env.has_key?('weak')
        r.etag 'foo', etag_opts
        'ok'
      end
    end
  end

  it 'uses a weak etag with the :weak option' do
    header('ETag', 'weak'=>true).should == 'W/"foo"'
  end

  describe 'for GET requests' do
    def res(a={})
      s, h, b = req(a)
      h['ETag'].should == '"foo"'
      [s, b.join]
    end

    it "sets etag if no If-None-Match" do
      res.should == [200, 'ok']
    end

    it "sets etag and returns 304 if If-None-Match is *" do
      res('HTTP_IF_NONE_MATCH' => '*').should == [304, '']
    end

    it "sets etag and if If-None-Match is * and it is a new resource" do
      res('HTTP_IF_NONE_MATCH' => '*', 'new_resource'=>true).should == [200, 'ok']
    end

    it "sets etag and returns 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"').should == [304, '']
    end

    it "sets etag and returns 304 if If-None-Match includes etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "foo"').should == [304, '']
    end

    it "sets etag if If-None-Match does not include etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "baz"').should == [200, 'ok']
    end

    it "sets etag and does not change status code if status code set and not 2xx or 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>499).should == [499, 'ok']
    end

    it "sets etag and returns 304 if status code set to 2xx if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>201).should == [304, '']
    end

    it "sets etag and returns 304 if status code is already 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>304).should == [304, '']
    end

    it "sets etag if If-Match is *" do
      res('HTTP_IF_MATCH' => '*').should == [200, 'ok']
    end

    it "sets etag if If-Match is etag" do
      res('HTTP_IF_MATCH' => '"foo"').should == [200, 'ok']
    end

    it "sets etag if If-Match includes etag" do
      res('HTTP_IF_MATCH' => '"bar", "foo"').should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-Match is * for new resources" do
      res('HTTP_IF_MATCH' => '*', 'new_resource'=>true).should == [412, '']
    end

    it "sets etag if If-Match does not include etag" do
      res('HTTP_IF_MATCH' => '"bar", "baz"', 'new_resource'=>true).should == [412, '']
    end
  end

  describe 'for PUT requests' do
    def res(a={})
      s, h, b = req(a.merge('REQUEST_METHOD'=>'PUT'))
      h['ETag'].should == '"foo"'
      [s, b.join]
    end

    it "sets etag if no If-None-Match" do
      res.should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-None-Match is *" do
      res('HTTP_IF_NONE_MATCH' => '*').should == [412, '']
    end

    it "sets etag and if If-None-Match is * and it is a new resource" do
      res('HTTP_IF_NONE_MATCH' => '*', 'new_resource'=>true).should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"').should == [412, '']
    end

    it "sets etag and returns 412 if If-None-Match includes etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "foo"').should == [412, '']
    end

    it "sets etag if If-None-Match does not include etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "baz"').should == [200, 'ok']
    end

    it "sets etag and does not change status code if status code set and not 2xx or 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>499).should == [499, 'ok']
    end

    it "sets etag and returns 304 if status code set to 2xx if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>201).should == [412, '']
    end

    it "sets etag and returns 304 if status code is already 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>304).should == [412, '']
    end

    it "sets etag if If-Match is *" do
      res('HTTP_IF_MATCH' => '*').should == [200, 'ok']
    end

    it "sets etag if If-Match is etag" do
      res('HTTP_IF_MATCH' => '"foo"').should == [200, 'ok']
    end

    it "sets etag if If-Match includes etag" do
      res('HTTP_IF_MATCH' => '"bar", "foo"').should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-Match is * for new resources" do
      res('HTTP_IF_MATCH' => '*', 'new_resource'=>true).should == [412, '']
    end

    it "sets etag if If-Match does not include etag" do
      res('HTTP_IF_MATCH' => '"bar", "baz"', 'new_resource'=>true).should == [412, '']
    end
  end

  describe 'for POST requests' do
    def res(a={})
      s, h, b = req(a.merge('REQUEST_METHOD'=>'POST'))
      h['ETag'].should == '"foo"'
      [s, b.join]
    end

    it "sets etag if no If-None-Match" do
      res.should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-None-Match is * and it is not a new resource" do
      res('HTTP_IF_NONE_MATCH' => '*', 'new_resource'=>false).should == [412, '']
    end

    it "sets etag and if If-None-Match is *" do
      res('HTTP_IF_NONE_MATCH' => '*').should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"').should == [412, '']
    end

    it "sets etag and returns 412 if If-None-Match includes etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "foo"').should == [412, '']
    end

    it "sets etag if If-None-Match does not include etag" do
      res('HTTP_IF_NONE_MATCH' => '"bar", "baz"').should == [200, 'ok']
    end

    it "sets etag and does not change status code if status code set and not 2xx or 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>499).should == [499, 'ok']
    end

    it "sets etag and returns 304 if status code set to 2xx if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>201).should == [412, '']
    end

    it "sets etag and returns 304 if status code is already 304 if If-None-Match is etag" do
      res('HTTP_IF_NONE_MATCH' => '"foo"', 'status'=>304).should == [412, '']
    end

    it "sets etag if If-Match is * and this is not a new resource" do
      res('HTTP_IF_MATCH' => '*', 'new_resource'=>false).should == [200, 'ok']
    end

    it "sets etag if If-Match is etag" do
      res('HTTP_IF_MATCH' => '"foo"').should == [200, 'ok']
    end

    it "sets etag if If-Match includes etag" do
      res('HTTP_IF_MATCH' => '"bar", "foo"').should == [200, 'ok']
    end

    it "sets etag and returns 412 if If-Match is * for new resources" do
      res('HTTP_IF_MATCH' => '*').should == [412, '']
    end

    it "sets etag if If-Match does not include etag" do
      res('HTTP_IF_MATCH' => '"bar", "baz"', 'new_resource'=>true).should == [412, '']
    end
  end
end
