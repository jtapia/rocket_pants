require 'spec_helper'

describe RocketPants, 'Configuration' do

  describe 'the environment' do

    around :each do |test|
      restoring_env 'RAILS_ENV', 'RACK_ENV' do
        with_config :env, nil, &test
      end
    end

    it 'should have an environment' do
      expect(RocketPants.env).to be_present
      expect(RocketPants.env).to be_a ActiveSupport::StringInquirer
    end

    it 'should set it correctly' do
      RocketPants.env = "my_new_env"
      expect(RocketPants.env).to eq("my_new_env")
      expect(RocketPants.env).to be_a ActiveSupport::StringInquirer
    end

    it 'should default to the Rails env if present' do
      ENV['RAILS_ENV'], ENV['RACK_ENV'] = "production", "staging"
      expect(RocketPants.env.production?).to eq true
      expect(RocketPants.env.staging?).to eq false
      expect(RocketPants.env.development?).to eq false
    end

    it 'should default to the rack env with no rails env if present' do
      ENV['RAILS_ENV'], ENV['RACK_ENV'] = nil, "staging"
      expect(RocketPants.env.production?).to eq false
      expect(RocketPants.env.staging?).to eq true
      expect(RocketPants.env.development?).to eq false
    end

    it 'should default to development otherwise' do
      ENV['RAILS_ENV'], ENV['RACK_ENV'] = nil, nil
      expect(RocketPants.env.production?).to eq false
      expect(RocketPants.env.staging?).to eq false
      expect(RocketPants.env.development?).to eq true
    end

    it 'should let you restore the environ`ent' do
      RocketPants.env = 'other'
      RocketPants.env = nil
      expect(RocketPants.env).to eq(RocketPants.default_env)
    end

  end

  describe 'passing through errors' do

    around :each do |test|
      with_config :pass_through_errors, nil, &test
    end

    it 'should allow you to force it to false' do
      RocketPants.pass_through_errors = false
      expect(RocketPants).to_not be_pass_through_errors
    end

    it 'should allow you to force it to true' do
      RocketPants.pass_through_errors = true
      expect(RocketPants).to be_pass_through_errors
    end

    it 'should default to if the env is dev or test' do
      %w(development test).each do |environment|
        allow(RocketPants).to receive(:env) { ActiveSupport::StringInquirer.new environment }
        RocketPants.pass_through_errors = nil
        expect(RocketPants).to be_pass_through_errors
      end
    end

    it 'should default to false in other envs' do
      %w(production staging).each do |environment|
        allow(RocketPants).to receive(:env) { ActiveSupport::StringInquirer.new environment }
        RocketPants.pass_through_errors = nil
        expect(RocketPants).to_not be_pass_through_errors
      end
    end

  end

  describe 'showing exception messages' do

    around :each do |test|
      with_config :show_exception_message, nil, &test
    end

    it 'should allow you to force it to false' do
      RocketPants.show_exception_message = false
      expect(RocketPants).to_not be_show_exception_message
    end

    it 'should allow you to force it to true' do
      RocketPants.show_exception_message = true
      expect(RocketPants).to be_show_exception_message
    end

    it 'should default to true in test and development' do
      %w(development test).each do |environment|
        allow(RocketPants).to receive(:env) { ActiveSupport::StringInquirer.new environment }
        RocketPants.show_exception_message = nil
        expect(RocketPants).to be_show_exception_message
      end
    end

    it 'should default to false in other environments' do
      %w(production staging somethingelse).each do |environment|
        allow(RocketPants).to receive(:env) { ActiveSupport::StringInquirer.new environment }
        RocketPants.show_exception_message = nil
        expect(RocketPants).to_not be_show_exception_message
      end
    end

  end

end
