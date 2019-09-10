require 'spec_helper'
require 'logger'
require 'stringio'
require 'will_paginate/collection'

describe RocketPants::Base do
  include ControllerHelpers

  describe 'integration' do

    it 'should have the authorization helper methods' do
      instance = controller_class.new
      expect(instance).to respond_to :authenticate_or_request_with_http_basic
      expect(instance).to respond_to :authenticate_or_request_with_http_digest
      expect(instance).to respond_to :authenticate_or_request_with_http_token
    end

    context 'with a valid model' do

      let(:table_manager) { ReversibleData.manager_for(:users) }

      before(:each) { table_manager.up! }
      after(:each)  { table_manager.down! }

      it 'should let you expose a single item' do
        user = User.create :age => 21
        allow(TestController).to receive(:test_data) { user }
        get :test_data
        expect(content[:response]).to eq(user.serializable_hash)
      end

      it 'should let you expose a collection' do
        1.upto(5) do |offset|
          User.create :age => (18 + offset)
        end
        allow(TestController).to receive(:test_data) { User.all }
        get :test_data
        expect(content[:response]).to eq(User.all.map(&:serializable_hash))
        expect(content[:count]).to eq(5)
      end

      it 'should let you expose a scope' do
        1.upto(5) do |offset|
          User.create :age => (18 + offset)
        end
        allow(TestController).to receive(:test_data) { User.where('1 = 1') }
        get :test_data
        expect(content[:response]).to eq(User.all.map(&:serializable_hash))
        expect(content[:count]).to eq(5)
      end

    end

    context 'with a invalid model' do
      let(:table_manager) { ReversibleData.manager_for(:fish) }

      before(:each) { table_manager.up! }
      after(:each)  { table_manager.down! }

      it 'should let you expose a invalid ActiveRecord:Base' do
        fish = Fish.create
        allow(TestController).to receive(:test_data) { fish }
        get :test_data
        expect(content['error']).to eq('invalid_resource')
        expect(content['messages']).to be_present
      end
    end

  end

  describe 'versioning' do

    it 'should be ok with an optional prefix with the specified prefix' do
      get :echo, {}, :version => 'v1', :rp_prefix => {:text => "v", :required => false}
      expect(content[:error]).to be_nil
    end

    it 'should be ok with an optional prefix without the specified prefix' do
      get :echo, {}, :version => '1', :rp_prefix => {:text => "v", :required => false}
      expect(content[:error]).to be_nil
    end

    it 'should be ok with a required prefix and one given' do
      get :echo, {}, :version => 'v1', :rp_prefix => {:text => "v", :required => true}
      expect(content[:error]).to be_nil
    end

    it 'should return an error when a prefix is required and not given' do
      get :echo, {}, :version => '1', :rp_prefix => {:text => "v", :required => true}
      expect(content[:error]).to eq('invalid_version')
    end

    it 'should return an error when a prefix is required and a different one is given' do
      get :echo, {}, :version => 'x1', :rp_prefix => {:text => "v", :required => true}
      expect(content[:error]).to eq('invalid_version')
    end

    it 'should return an error when an optional prefix is allowed and a different one is given' do
      get :echo, {}, :version => 'x1', :rp_prefix => {:text => "v", :required => false}
      expect(content[:error]).to eq('invalid_version')
    end

    it 'should return an error when a prefix is now allowed and is given' do
      get :echo, {}, :version => 'v1'
      expect(content[:error]).to eq('invalid_version')
    end

    it 'should be ok with a valid version' do
      %w(1 2).each do |version|
        get :echo, {}, :version => version.to_s
        expect(content[:error]).to be_nil
      end
    end

    it 'should return an error for an invalid version number' do
      [0, 3, 10, 2.5, 2.2, '1.1'].each do |version|
        get :echo, {}, :version => version.to_s
        expect(content[:error]).to eq('invalid_version')
      end
    end

    it 'should return an error for no version number' do
      get :echo, {}, :version => nil
      expect(content[:error]).to eq('invalid_version')
    end

  end

  describe 'respondable' do
    let(:content_type) { Mime::HTML }

    it 'should correctly convert a normal collection' do
      allow(TestController).to receive(:test_data) { %w(a b c d) }
      get :test_data
      expect(content[:response]).to eq(%w(a b c d))
      expect(content[:pagination]).to be_nil
      expect(content[:count]).to eq(4)
    end

    it 'should correctly convert a normal object' do
      object = {:a => 1, :b => 2}
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      expect(content[:count]).to be_nil
      expect(content[:pagination]).to be_nil
      expect(content[:response]).to eq({'a' => 1, 'b' => 2})
    end

    it 'should correctly convert an object with a serializable hash method' do
      object = {:a => 1, :b => 2}
      def object.serializable_hash(*); {:serialised => true}; end
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      expect(content[:response]).to eq({'serialised' => true})
    end

    it 'should correct convert an object with as_json' do
      object = {:a => 1, :b => 2}
      allow(object).to receive(:as_json).with(anything) { { :serialised => true } }
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      expect(content[:response]).to eq({'serialised' => true})
    end

    it 'should correctly hook into paginated responses' do
      pager = WillPaginate::Collection.create(2, 10) { |p| p.replace %w(a b c d e f g h i j); p.total_entries = 200 }
      allow(TestController).to receive(:test_data) { pager }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(pager, :paginated, false) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(pager, :paginated, false) { hooks << :post }
      get :test_data
      expect(hooks).to eq([:pre, :post])
    end

    it 'should correctly hook into collection responses' do
      object = %w(a b c d)
      allow(TestController).to receive(:test_data) { object }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(object, :collection, false) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(object, :collection, false) { hooks << :post }
      get :test_data
      expect(hooks).to eq([:pre, :post])
    end

    it 'should correctly hook into singular responses' do
      object = {:a => 1, :b => 2}
      allow(TestController).to receive(:test_data) { object }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(object, :resource, true) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(object, :resource, true) { hooks << :post }
      get :test_data
      expect(hooks).to eq([:pre, :post])
    end

    it 'should accept status options when rendering json' do
      allow(TestController).to receive(:test_data)    { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_render_json
      expect(response.status).to eq(201)
    end

    it 'should accept status options when responding with data' do
      allow(TestController).to receive(:test_data)    { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_responds
      expect(response.status).to eq(201)
    end

    it 'should accept status options when responding with a single object' do
      allow(TestController).to receive(:test_data)    { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      expect(response.status).to eq(201)
    end

    it 'should accept status options when responding with a paginated collection' do
      allow(TestController).to receive(:test_data) do
        WillPaginate::Collection.create(1, 1) {|c| c.replace([{:hello => "World"}]); c.total_entries = 1 }
      end
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      expect(response.status).to eq(201)
    end

    it 'should accept status options when responding with collection' do
      allow(TestController).to receive(:test_data)    { [{:hello => "World"}] }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      expect(response.status).to eq(201)
    end

    xit 'should let you override the content type' do
      allow(TestController).to receive(:test_data)    { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:content_type => content_type} }
      get :test_data
      expect(response.headers['Content-Type']).to match(/text\/html/)
    end

  end

  describe 'caching' do

    let!(:controller_class)    { Class.new TestController }

    it 'should use a set for storing the cached actions' do
      expect(controller_class.cached_actions).to be_a Set
      expect(controller_class.cached_actions).to eq(Set.new)
    end

    it 'should default the caching timeout' do
    end

    it 'should let you set the caching timeout' do
      expect do
        controller_class.caches :test_data, :cache_for => 10.minutes
        expect(controller_class.caching_timeout).to eq(10.minutes)
      end.to change(controller_class, :caching_timeout)
    end

    it 'should let you set which actions should be cached' do
      expect(controller_class.cached_actions).to be_empty
      controller_class.caches :test_data
      expect(controller_class.cached_actions).to eq(["test_data"].to_set)
    end

    describe 'when dealing with the controller' do

      it 'should invoke the caching callback with caching enabled' do
        set_caching_to true do
          allow_any_instance_of(controller_class).to receive(:cache_response)
          get :test_data
        end
      end

      it 'should not invoke the caching callback with caching disabled' do
        set_caching_to false do
          # dont_allow_any_instance_of(controller_class).cache_response.with_any_args
          get :test_data
        end
      end

      before :each do
        controller_class.caches :test_data
      end

      around :each do |t|
        set_caching_to true, &t
      end

      context 'with a singular response' do

        let(:cached_object) { Object.new }

        before :each do
          allow(RocketPants::Caching).to receive(:cache_key_for).with(cached_object) { "my-object" }
          allow(RocketPants::Caching).to receive(:etag_for).with(cached_object)      { "my-object:stored-etag" }
          allow(controller_class).to receive(:test_data) { cached_object }
        end

        it 'should invoke the caching callback correctly' do
          allow_any_instance_of(controller_class).to receive(:cache_response).with(cached_object, true)
          get :test_data
        end

        it 'should not set the expires in time' do
          get :test_data
          expect(response['Cache-Control'].to_s).to_not match(/max-age=(\d+)/)
        end

        it 'should set the response etag' do
          get :test_data
          expect(response['ETag']).to eq('"my-object:stored-etag"')
        end

      end

      context 'with a collection response' do

        let(:cached_objects) { [Object.new] }

        before :each do
          # dont_allow(RocketPants::Caching).cache_key_for.with_any_args
          # dont_allow(RocketPants::Caching).etag_for.with_any_args
          allow(controller_class).to receive(:test_data) { cached_objects }
        end

        it 'should invoke the caching callback correctly' do
          allow_any_instance_of(controller_class).to receive(:cache_response).with(cached_objects, false)
          get :test_data
        end

        it 'should set the expires in time' do
          get :test_data
          expect(response['Cache-Control'].to_s).to match(/max-age=(\d+)/)
        end

        it 'should not set the response etag' do
          get :test_data
          expect(response["ETag"]).to be_nil
        end

      end

    end

  end

  describe 'jsonp support' do

    let!(:first_controller) { Class.new(TestController)   }
    let!(:controller_class) { Class.new(first_controller) }

    it 'should let you specify requests as having jsonp' do
      controller_class.jsonp
      get :echo, :echo => "Hello World"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/javascript'
      expect(response.body).to eq(%|test({"response":{"echo":"Hello World"}});|)
    end

    it 'should automatically inherit it' do
      first_controller.jsonp :enable => true
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/javascript'
      expect(response.body).to eq(%|test({"response":{"echo":"Hello World"}});|)
      get :echo, :echo => "Hello World", :other_callback => "test"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
    end

    it 'should allow you to disable at a lower level' do
      first_controller.jsonp :enable => true
      controller_class.jsonp :enable => false
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
    end

    it 'should let you specify options to it' do
      controller_class.jsonp :parameter => 'cb'
      get :echo, :echo => "Hello World", :cb => "test"
      expect(response.content_type).to include 'application/javascript'
      expect(response.body).to eq(%|test({"response":{"echo":"Hello World"}});|)
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
    end

    it 'should let you specify it on a per action level' do
      controller_class.jsonp :only => [:test_data]
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
      allow(controller_class).to receive(:test_data) { {"other" => true} }
      get :test_data, :callback => "test"
      expect(response.content_type).to include 'application/javascript'
      expect(response.body).to eq(%|test({"response":{"other":true}});|)
    end

    it 'should not wrap non-get actions' do
      controller_class.jsonp
      post :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/json'
      expect(response.body).to eq(%({"response":{"echo":"Hello World"}}))
    end

    it 'should have the correct content length' do
      controller_class.jsonp
      get :echo, :echo => "Hello World", :callback => "test"
      expect(response.content_type).to include 'application/javascript'
      expect(response.body).to eq(%|test({"response":{"echo":"Hello World"}});|)
      expect(response.headers['Content-Length'].to_i).to eq(response.body.bytesize)
    end

  end

  describe 'custom metadata' do

    xit 'should allow custom metadata' do
      get :test_metadata, :metadata => {:awesome => "1"}
      decoded = ActiveSupport::JSON.decode(response.body)
      expect(decoded["awesome"]).to eq("1")
    end

  end

  context 'empty responses' do

    it 'correctly returns a blank body' do
      get :test_head
      expect(response.status).to eq(201)
      expect(response.body).to be_blank
      expect(response.content_type).to include 'application/json'
    end

  end

end
