require 'spec_helper'
require 'will_paginate/collection'

describe RocketPants::HeaderMetadata do
  include ControllerHelpers

  context 'metadata' do

    let(:table_manager) { ReversibleData.manager_for(:users) }
    let(:pager) do
      WillPaginate::Collection.create(2, 10) do |p|
        p.replace %w(a b c d e f g h i j)
        p.total_entries = 200
      end
    end

    before(:each) { table_manager.up! }
    after(:each)  { table_manager.down! }

    let(:users) do
      1.upto(5) do |offset|
        User.create :age => (18 + offset)
      end
      User.all
    end

    it 'should not include header metadata by default' do
      allow(TestController).to receive(:test_data) { users }
      get :test_data
      expect(response.headers).not_to have_key 'X-Api-Count'
    end

    it 'should let you turn on header metadata' do
      with_config :header_metadata, true do
        allow(TestController).to receive(:test_data) { users }
        get :test_data
        expect(response.headers).to have_key 'X-Api-Count'
        expect(response.headers['X-Api-Count']).to eq users.size.to_s
      end
    end

    it 'should handle nested (e.g. pagination) metadata correctly' do
      with_config :header_metadata, true do
        allow(TestController).to receive(:test_data) { pager }
        get :test_data
        h = response.headers
        expect(h['X-Api-Pagination-Next']).to eq '3'
        expect(h['X-Api-Pagination-Current']).to eq '2'
        expect(h['X-Api-Pagination-Previous']).to eq '1'
        expect(h['X-Api-Pagination-Pages']).to eq '20'
        expect(h['X-Api-Pagination-Count']).to eq '200'
        expect(h['X-Api-Pagination-Per-Page']).to eq '10'
        expect(h['X-Api-Count']).to eq '10'
      end
    end

  end

end
