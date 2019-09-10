require 'spec_helper'

describe RocketPants::Errors do

  describe 'getting all errors' do

    it 'should return a list of all errors' do
      list = RocketPants::Errors.all
      expect(list).to be_present
      expect(list.keys).to   be_all { |v| v.is_a?(Symbol) }
      expect(list.values).to be_all { |v| v < RocketPants::Error }
    end

    it 'should return a muteable list' do
      list = RocketPants::Errors.all
      expect(list).to_not have_key(:my_error)
      RocketPants::Errors.register! :my_error
      expect(list).to_not have_key(:my_error)
      new_list = RocketPants::Errors.all
      expect(new_list).to_not eq(list)
      expect(new_list).to have_key(:my_error)
    end

  end

  describe 'getting an error from a key' do

    it 'should let you use an error you have registered before' do
      RocketPants::Errors.all.each_pair do |key, value|
        expect(RocketPants::Errors[key]).to eq(value)
      end
      RocketPants::Errors.register! :ninja_error
      expect(RocketPants::Errors[:ninja_error]).to eq(RocketPants::NinjaError)
    end


    it 'should return nil for unknown errors' do
      expect(RocketPants::Errors[:life_the_universe_and_everything]).to be_nil
    end

  end

  describe 'adding a new error' do

    it 'should add it to the mapping' do
      expect(RocketPants::Errors[:fourty_two]).to be_nil
      error = Class.new(RocketPants::Error)
      error.error_name :fourty_two
      RocketPants::Errors.add error
      expect(RocketPants::Errors[:fourty_two]).to eq(error)
    end

  end

  describe 'registering an error' do

    it 'should add a constant' do
      expect(RocketPants).to_not be_const_defined(:AnotherException)
      RocketPants::Errors.register! :another_exception
      expect(RocketPants).to be_const_defined(:AnotherException)
      expect(RocketPants::AnotherException).to be < RocketPants::Error
    end

    it 'should let you set the parent object' do
      RocketPants::Errors.register! :test_base_exception
      RocketPants::Errors.register! :test_child_exception, :base => RocketPants::TestBaseException
      expect(RocketPants).to be_const_defined(:TestBaseException)
      expect(RocketPants).to be_const_defined(:TestChildException)
      expect(RocketPants::TestChildException).to be < RocketPants::TestBaseException
    end

    it 'should let you set the parent object' do
      expect do
        RocketPants::Errors.register! :test_child_exception_bad_base, :base => StandardError
      end.to raise_error ArgumentError
      expect(RocketPants).to be_const_defined(:TestBaseException)
      expect(RocketPants).to_not be_const_defined(:TestChildExceptionBadBase)
    end

    it 'should let you set the http status' do
      RocketPants::Errors.register! :another_exception_two, :http_status => :forbidden
      expect(RocketPants::Errors[:another_exception_two].http_status).to eq(:forbidden)
    end

    it 'should let you set the error name' do
      expect(RocketPants::Errors[:threes_a_charm]).to be_blank
      RocketPants::Errors.register! :another_exception_three, :error_name => :threes_a_charm
      expect(RocketPants::Errors[:threes_a_charm]).to be_present
    end

    it 'should let you set the class name' do
      expect(RocketPants).to_not be_const_defined(:NumberFour)
      RocketPants::Errors.register! :another_exception_four, :class_name => 'NumberFour'
      expect(RocketPants).to be_const_defined(:NumberFour)
      expect(RocketPants::Errors[:another_exception_four]).to eq(RocketPants::NumberFour)
    end

    it 'should let you register an error under a scope' do
      my_scope = Class.new
      expect(my_scope).to_not be_const_defined(:AnotherExceptionFive)
      expect(RocketPants).to_not be_const_defined(:AnotherExceptionFive)
      RocketPants::Errors.register! :another_exception_five, :under => my_scope
      expect(RocketPants).to_not be_const_defined(:AnotherExceptionFive)
      expect(my_scope).to be_const_defined(:AnotherExceptionFive)
      expect(RocketPants::Errors[:another_exception_five]).to eq(my_scope::AnotherExceptionFive)
    end

  end

end
