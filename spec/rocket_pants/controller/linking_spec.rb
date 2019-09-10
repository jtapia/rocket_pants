require 'spec_helper'
require 'will_paginate/collection'

describe RocketPants::Linking do
  include ControllerHelpers

  around :each do |test|
    with_config :header_metadata, true do
      test.call
    end
  end

  let(:controller_class) { Class.new TestController }

  def link_portion(&blk)
    controller_class.send :define_method, :test_data, &blk
    get :test_data
  end

  describe 'automatic pagination links'  do

    let(:current_page) { @current_page ||= 2 }
    let(:pagination)   { WillPaginate::Collection.create(current_page, 10) { |p| p.replace %w(a b c d e f g h i j); p.total_entries = 200 } }

    before :each do
      allow(controller_class).to receive(:test_data) { pagination }
      # Test Item...
      controller_class.send(:define_method, :page_url) do |page|
        "page#{page}"
      end
    end

    it 'should not include invalid links' do
      @current_page = 1
      get :test_data
      links = response.headers['Link']
      expect(links.size).to eq 3
      expect(links.map { |i| i[/rel=\"(.*)\"/, 1] }).to match_array %w(next last first)
      expect(links.map { |i| i[/<(.*)>/, 1] }).to match_array %w(page1 page2 page20)
    end

    it 'should not include links without a pagination url method' do
      controller_class.send(:define_method, :page_url) { |item| nil }
      get :test_data
      expect(response.headers['Link']).to be_blank
    end

    it 'should generate all links where possible' do
      @current_page = 2
      get :test_data
      links = response.headers['Link']
      expect(links.size).to eq 4
      expect(links.map { |i| i[/rel=\"(.*)\"/, 1] }).to match_array %w(next last first prev)
      expect(links.map { |i| i[/<(.*)>/, 1] }).to match_array %w(page1 page1 page3 page20)
    end

  end

  describe 'custom link generation' do

    it 'should let you add a link tag' do
      link_portion { link :search, "http://google.com/" }
      links = response.headers['Link']
      expect(links).to be_present
      expect(links.size).to eq 1
      expect(links.first.strip).to eq "<http://google.com/>; rel=\"search\""
    end

    it 'should allow extra attributes' do
      link_portion { link :search, "http://google.com/", :awesome => "Sure Am" }
      links = response.headers['Link']
      expect(links).to be_present
      expect(links.size).to eq 1
      parts = links.first.strip.split(";").map(&:strip)
      link = parts.shift
      expect(parts).to match_array ["awesome=\"Sure Am\"", "rel=\"search\""]
    end

  end

  describe 'generating multiple links' do

    it 'should provide a shorthand to generate multiple links' do
      link_portion { links :next => "http://example.com/page/3", :prev => "http://example.com/page/1" }
      links = response.headers['Link']
      expect(links).to be_present
      expect(links.size).to eq 2
      expect(links).to match_array ["<http://example.com/page/3>; rel=\"next\"", "<http://example.com/page/1>; rel=\"prev\""]
    end

    it 'should combine multiple links into a single header' do
      link_portion do
        link :next, "http://example.com/page/3"
        link :prev, "http://example.com/page/1"
      end
      links = response.headers['Link']
      expect(links).to be_present
      expect(links.size).to eq 2
      expect(links).to match_array ["<http://example.com/page/3>; rel=\"next\"", "<http://example.com/page/1>; rel=\"prev\""]
    end

  end

end
