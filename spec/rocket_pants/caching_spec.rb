require 'spec_helper'
# require 'byebugObject.new.tap { |i|'

describe RocketPants::Caching do

  let(:object) { Object.new }

  before do
    allow(object).to receive(:id).and_return(10)
  end

  describe 'dealing with the etag cache' do

    it 'should let you remove an item from the cache' do
      allow(object).to receive(:id).and_return(10)
      expect(RocketPants::Caching).to receive(:cache_key_for).with(object) { 'my-cache-key' }
      RocketPants.cache['my-cache-key'] = 'hello there'
      RocketPants::Caching.remove object
      RocketPants.cache['my-cache-key'].should be_nil
    end

    it 'should safely delete a non-existant item from the cache' do
      expect do
        RocketPants::Caching.remove object
      end.to_not raise_error
    end

    it 'should let you record an object in the cache with a cache_key method' do
      expect(RocketPants::Caching).to receive(:cache_key_for).with(object) { 'my-cache-key' }
      expect(object).to receive(:cache_key) { 'hello' }
      RocketPants::Caching.record object
      expect(RocketPants.cache['my-cache-key']).to eq(Digest::MD5.hexdigest('hello'))
    end

    it 'should let you record an object in the cache with the default inspect value' do
      expect(RocketPants::Caching).to receive(:cache_key_for).with(object) { 'my-cache-key' }
      RocketPants::Caching.record object
      expect(RocketPants.cache['my-cache-key']).to eq(Digest::MD5.hexdigest(object.inspect))
    end

  end

  describe 'computing the cache key for an object' do

    it 'should return a md5-like string' do
      RocketPants::Caching.cache_key_for(object).should =~ /\A[a-z0-9]{32}\Z/
    end

    it 'should use the rp_object_key method if present' do
      expect(object).to receive(:rp_object_key) { 'hello' }
      expect(RocketPants::Caching.cache_key_for(object)).to eq(Digest::MD5.hexdigest('hello'))
    end

    it 'should build a default cache key for records with new? that are new' do
      expect(object).to receive(:new?) { true }
      expect(RocketPants::Caching.cache_key_for(object)).to eq(Digest::MD5.hexdigest('Object/new'))
    end

    it 'should build a default cache key for records with new? that are old' do
      expect(object).to receive(:new?) { false }
      expect(RocketPants::Caching.cache_key_for(object)).to eq(Digest::MD5.hexdigest('Object/10'))
    end

    it 'should build a default cache key for records without new' do
      expect(RocketPants::Caching.cache_key_for(object)).to eq(Digest::MD5.hexdigest('Object/10'))
    end

  end

  describe 'normalising an etag' do

    it 'should correctly convert it to the string' do
      def object.to_s; 'Hello-World'; end
      expect(object).to receive(:to_s) { 'Hello-World' }
      expect(described_class.normalise_etag(object)).to eq('"Hello-World"')
    end

    it 'should correctly deal with a basic case' do
      described_class.normalise_etag('SOMETAG').should == '"SOMETAG"'
    end

  end

  describe 'fetching an object etag' do

    before :each do
      allow(RocketPants::Caching).to receive(:cache_key_for).with(object) { 'my-cache-key' }
    end

    it 'should use the cache key as a prefix' do
      expect(RocketPants::Caching.etag_for(object)).to match(/\Amy-cache-key\:/)
    end

    it 'should fetch the recorded etag' do
      RocketPants.cache['my-cache-key'] = 'hello-world'
      RocketPants::Caching.etag_for(object)
    end

    it 'should generate a new etag if one does not exist' do
      RocketPants::Caching.record object, 'my-cache-key'
      RocketPants.cache['my-cache-key'] = nil
      RocketPants::Caching.etag_for(object)
    end

  end

end
