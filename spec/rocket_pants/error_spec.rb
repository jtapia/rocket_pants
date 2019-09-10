require 'spec_helper'

describe RocketPants::Error do

  def temporary_constant(items)
    items.each_pair do |k, v|
      Object.const_set k, v
    end
    yield if block_given?
  ensure
    items.each_key do |name|
      Object.send :remove_const, name
    end
  end

  let!(:unchanged_error) do
    Class.new(RocketPants::Error)
  end

  let!(:attacked_by_ninjas) do
    Class.new(RocketPants::Error) do
      http_status 422
    end
  end

  let!(:another_error) do
    Class.new(attacked_by_ninjas) do
      http_status 404
      error_name :oh_look_a_panda
    end
  end

  around :each do |test|
    temporary_constant :AnotherError => another_error, :UnchangedError => unchanged_error, :AttackedByNinjas => attacked_by_ninjas do
      test.call
    end
  end

  it 'should be an exception' do
    expect(RocketPants::Error).to be < StandardError
  end

  describe 'working with the http status codes' do

    it 'should default to 400 for the status code' do
      expect(RocketPants::Error.http_status).to eq 400
      expect(unchanged_error.http_status).to eq 400
    end

    it 'should let you get the status code for a given class' do
      expect(attacked_by_ninjas.http_status).to eq 422
      expect(another_error.http_status).to eq 404
    end

    it 'should let you set the status code for a given class' do
      expect(attacked_by_ninjas.http_status).to eq 422
      another_error.http_status 403
      expect(another_error.http_status).to eq 403
      expect(attacked_by_ninjas.http_status).to eq 422
    end

    it 'should let you get the status code from an instance' do
      instance = another_error.new
      expect(instance.http_status).to eq another_error.http_status
    end

  end

  describe 'working with the error name' do

    it 'should have a sane default value' do
      expect(unchanged_error.error_name).to eq :unchanged
      expect(RocketPants::Error.error_name).to eq :unknown
      expect(attacked_by_ninjas.error_name).to eq :attacked_by_ninjas
    end

    it 'should let you get the error name for a given class' do
      expect(another_error.error_name).to eq :oh_look_a_panda
    end

    it 'should let you set the error name for a given class' do
      another_error.error_name :oh_look_a_pingu
      expect(another_error.error_name).to eq :oh_look_a_pingu
    end

    it 'should let you get it on an instance' do
      instance = attacked_by_ninjas.new
      expect(instance.error_name).to eq attacked_by_ninjas.error_name
    end

  end

  describe 'dealing with the error context' do

    it 'should let you set / get arbitrary context' do
      exception = RocketPants::Error.new
      exception.context = 'Something'
      expect(exception.context).to eq 'Something'
      exception.context = {:a => 'hash'}
      expect(exception.context).to eq({:a => 'hash'})
    end

    it 'should default the context to a hash' do
      expect(RocketPants::Error.new.context).to eq({})
    end

  end

  describe RocketPants::InvalidResource do

    let(:error_messages) { {:name => %w(a b c), :other => %w(e)} }

    it 'should let you pass in error messages' do
      o = Object.new
      allow(o).to receive(:to_hash) { error_messages }
      error = RocketPants::InvalidResource.new(o)
      expect(error.context).to eq({:metadata => {:messages => error_messages}})
    end

    it 'should not override messages' do
      error = RocketPants::InvalidResource.new(error_messages)
      error.context = {:other => true, :metadata => {:test => true}}
      expect(error.context).to eq({:metadata => {:messages => error_messages, :test => true}, :other => true})
    end

  end

end
