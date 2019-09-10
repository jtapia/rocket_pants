require 'spec_helper'

describe RocketPants::Base, 'strong parameters integration' do
  include ControllerHelpers

  before { pending "Strong parameters are included in rails 4." unless defined? ActionController::StrongParameters }

  let!(:controller_class) { Class.new(TestController) }

  it "should have action controller parameters in controller" do
    action_is { raise "no action controller parameters" unless params.is_a? ActionController::Parameters }
    expect{ get :test_data }.to_not raise_error
  end

  it "should map parameter missing error to bad request" do

    exception = ActionController::ParameterMissing.new :foo
    allow(controller_class).to receive(:test_error) { raise exception  }

    with_config :pass_through_errors, false do
      get :test_error
      expect(content[:error]).to eq "bad_request"
      expect(content[:error_description]).to eq exception.message
      expect(response).to be_bad_request
    end
  end

  it "should map unpermitted parameters error to bad request" do
    exception = ActionController::UnpermittedParameters.new [:foo, :bar]
    allow(controller_class).to receive(:test_error) { raise exception }

    with_config :pass_through_errors, false do
      get :test_error
      expect(content[:error]).to eq "bad_request"
      expect(content[:error_description]).to eq exception.message
      expect(response).to be_bad_request
    end
  end
end
