require 'spec_helper'

xdescribe RocketPants::Base, 'kaminari integration', :integration => true, :target => 'kaminari' do
  include ControllerHelpers

  before :all do
    begin
      stderr, $stderr = $stderr, StringIO.new
      require 'kaminari'
      Kaminari::Hooks.init if defined?(Kaminari::Hooks.init)
    ensure
      $stderr = stderr
    end
  end

  describe 'on models' do

    use_reversible_tables :users, :scope => :all

    before :all do
      25.times { |i| User.create :age => (18 + i) }
    end

    it 'correctly works with an empty page' do
      expect(TestController).to receive(:test_data) { User.where('0').page(1).per(5) }
      get :test_data
      expect(content[:response]).to eq([])
      expect(content[:count]).to eq(0)
      expect(content[:pagination]).to be_present
      expect(content[:pagination][:count]).to eq(0)
      expect(content[:pagination][:next]).to be_nil
    end

    it 'should let you expose a kaminari-paginated collection' do
      expect(TestController).to receive(:test_data) { User.page(1).per(5) }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:count]).to eq(5)
      expect(content[:pagination]).to be_present
      expect(content[:pagination][:count]).to eq(25)
    end

    it 'should not expose non-paginated as paginated' do
      expect(TestController).to receive(:test_data) { User.all }
      get :test_data
      expect(content[:response]).to be_present
      expect(content[:count]).to eq(25)
      expect(content[:pagination]).to_not be_present
    end

  end

  describe 'on arrays' do

    it 'should correctly convert a kaminari array' do
      pager = Kaminari::PaginatableArray.new((1..200).to_a, :limit => 10, :offset => 10)
      allow(TestController).to receive(:test_data) { pager }
      get :test_data
      expect(content).to have_key(:pagination)
      expect(content[:pagination]).to eq({
        :next => 3,
        :current => 2,
        :previous => 1,
        :pages => 20,
        :count => 200,
        :per_page => 10
      }.stringify_keys)
      expect(content).to have_key(:count)
      expect(content[:count]).to eq(10)
    end

  end

end
