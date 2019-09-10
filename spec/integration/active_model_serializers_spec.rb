require 'spec_helper'
require 'active_model_serializers'

xdescribe RocketPants::Base, 'active_model_serializers integration', :integration => true, :target => 'active_model_serializers' do
  include ControllerHelpers

  use_reversible_tables :fish, :scope => :all

  # t.string  :name
  # t.string  :latin_name
  # t.integer :child_number
  # t.string  :token

  let(:fish)   { Fish.create! :name => "Test Fish", :latin_name => "Fishus fishii", :child_number => 1, :token => "xyz" }
  after(:each) { Fish.delete_all }

  class SerializerA < ActiveModel::Serializer
    attributes :name, :latin_name
  end

  class SerializerB < ActiveModel::Serializer
    attributes :name, :child_number
  end

  describe 'on instances' do

    it 'should let you disable the serializer' do
      with_config :serializers_enabled, false do
        allow(TestController).to receive(:test_data) { fish }
        # dont_allow(fish).active_model_serializer
        get :test_data
        expect(content[:response]).to be_present
        expect(content[:response]).to be_a Hash
      end
    end

    it 'should use the active_model_serializer' do
      allow(TestController).to receive(:test_data) { fish }
      allow(fish).active_model_serializer { SerializerB }
      allow(SerializerB).to receive(:new).with(fish, anything) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Hash
      expect(content[:response].keys.map(&:to_sym)).to match_array([:name, :child_number])
    end

    it 'should let you specify a custom serializer' do
      allow(TestController).to receive(:test_data) { fish }
      allow(TestController).to receive(:test_options) { {:serializer => SerializerA} }
      allow(SerializerA).to receive(:new).with(fish, anything) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Hash
      expect(content[:response].keys.map(&:to_sym)).to match_array([:name, :latin_name])
    end

    it 'should use serializable_hash without a serializer' do
      # dont_allow(SerializerA).new(fish, anything)
      # dont_allow(SerializerB).new(fish, anything)
      allow(TestController).to receive(:test_data) { fish }
      expected_keys = fish.serializable_hash.keys.map(&:to_sym)
      allow(fish).to receive(:serializable_hash) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Hash
      expect(content[:response].keys.map(&:to_sym)).to match(expected_keys)
    end

    it 'should pass through url options' do
      allow(TestController).to receive(:test_data) { fish }
      allow(TestController).to receive(:test_options) { {:serializer => SerializerA} }
      allow(SerializerA).to receive(:new).with(fish, rr_satisfy { |h| h[:url_options].present? }) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Hash
      expect(content[:response].keys.map(&:to_sym)).to match_array([:name, :latin_name])
    end

  end

  describe 'on arrays' do

    it 'should work with array serializers' do
      allow(TestController).to receive(:test_data) { [fish] }
      allow(fish).to receive(:active_model_serializer) { SerializerB }
      allow(SerializerB).to receive(:new).with(fish, anything) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Array
      serialized_fish = content[:response].first
      expect(serialized_fish).to be_a Hash
      expect(serialized_fish.keys.map(&:to_sym)).to match_array([:name, :child_number])
    end

    it 'should support each_serializer' do
      allow(TestController).to receive(:test_data) { [fish] }
      allow(SerializerA).to receive(:new).with(fish, anything) { |r| r }
      allow(TestController).to receive(:test_options) { {:each_serializer => SerializerA} }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Array
      serialized_fish = content[:response].first
      expect(serialized_fish).to be_a Hash
      expect(serialized_fish.keys.map(&:to_sym)).to match_array([:name, :latin_name])
    end

    it 'should default to the serializable hash version' do
      # dont_allow(SerializerA).new(fish, anything)
      # dont_allow(SerializerB).new(fish, anything)
      allow(TestController).to receive(:test_data) { [fish] }
      expected_keys = fish.serializable_hash.keys.map(&:to_sym)
      allow(fish).to receive(:serializable_hash).with_any_args { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Array
      serialized_fish = content[:response].first
      expect(serialized_fish).to be_a Hash
      expect(serialized_fish.keys.map(&:to_sym)).to match(expected_keys)
    end

    it 'should pass through url options' do
      allow(TestController).to receive(:test_data) { [fish] }
      allow(TestController).to receive(:test_options) { {:each_serializer => SerializerA} }
      allow(SerializerA).to receive(:new).with(fish, rr_satisfy { |h| h[:url_options].present? }) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Array
      serialized_fish = content[:response].first
      expect(serialized_fish).to be_a Hash
      expect(serialized_fish.keys.map(&:to_sym)).to match_array([:name, :latin_name])
    end

    it 'should default to root being false' do
      allow(TestController).to receive(:test_data) { [fish] }
      allow(TestController).to receive(:test_options) { {:each_serializer => SerializerA} }
      allow(SerializerA).to receive(:new).with(fish, rr_satisfy { |h| h[:root] == false }) { |r| r }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:response]).to be_a Array
      serialized_fish = content[:response].first
      expect(serialized_fish).to be_a Hash
      expect(serialized_fish.keys.map(&:to_sym)).to match_array([:name, :latin_name])
    end

  end

end
