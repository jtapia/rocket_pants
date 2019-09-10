require 'spec_helper'

describe RocketPants::ErrorHandling do
  include ControllerHelpers

  let!(:controller_class) { Class.new(TestController) }

  context 'error handler functions' do

    context 'when pass_through_errors is false' do
      around :each do |test|
        with_config :pass_through_errors, false, &test
      end

      it 'should allow you to set the error handle from a named type' do
        expect(controller_class.exception_notifier_callback).to eq(controller_class::DEFAULT_NOTIFIER_CALLBACK)

        controller_class.use_named_exception_notifier :airbrake
        expect(controller_class.exception_notifier_callback).to_not eq(controller_class::DEFAULT_NOTIFIER_CALLBACK)
        expect(controller_class.exception_notifier_callback).to eq(controller_class::NAMED_NOTIFIER_CALLBACKS[:airbrake])

        controller_class.use_named_exception_notifier :honeybadger
        expect(controller_class.exception_notifier_callback).to_not eq(controller_class::DEFAULT_NOTIFIER_CALLBACK)
        expect(controller_class.exception_notifier_callback).to eq(controller_class::NAMED_NOTIFIER_CALLBACKS[:honeybadger])

        controller_class.use_named_exception_notifier :bugsnag
        expect(controller_class.exception_notifier_callback).to_not eq(controller_class::DEFAULT_NOTIFIER_CALLBACK)
        expect(controller_class.exception_notifier_callback).to eq(controller_class::NAMED_NOTIFIER_CALLBACKS[:bugsnag])

        controller_class.use_named_exception_notifier :nonexistent
        expect(controller_class.exception_notifier_callback).to eq(controller_class::DEFAULT_NOTIFIER_CALLBACK)
      end

      context 'named exception notifier' do
        let(:controller) { controller_class.new }

        let(:exception) { StandardError.new }

        let(:request) { Rack::Request.new({})}

        context 'airbrake' do
          let(:request_data) { { method: 'POST', path: '/' } }

          before :each do
            controller_class.use_named_exception_notifier :airbrake
            allow_any_instance_of(controller_class).to receive(:airbrake_local_request?) { false }
            allow_any_instance_of(controller_class).to receive(:airbrake_request_data) { request_data }

            Airbrake = Class.new do
              define_singleton_method(:notify) { |exception, request_data| }
            end
          end

          it 'should send notification when it is the named exception notifier' do
            Airbrake.notify(exception, request_data)

            controller_class.exception_notifier_callback.call(controller, exception, request)
          end
        end

        context 'honeybadger' do
          before :each do
            controller_class.use_named_exception_notifier :honeybadger
            allow_any_instance_of(controller_class).to receive(:notify_honeybadger) {}
          end

          it 'should send notification when it is the named exception notifier' do
            allow(controller).to receive(:notify_honeybadger).with(exception)

            controller_class.exception_notifier_callback.call(controller, exception, request)
          end
        end

        context 'bugsnag' do
          before :each do
            controller_class.use_named_exception_notifier :bugsnag
            allow_any_instance_of(controller_class).to receive(:notify_bugsnag) {}
            Bugsnag = Class.new do
              define_singleton_method(:notify) { |exception| }
            end
          end

          it 'should send notification when it is the named exception notifier' do
            controller.notify_bugsnag(exception, request: request)

            controller_class.exception_notifier_callback.call(controller, exception, request)
          end
        end
      end

      it 'should include the error identifier in the response if set' do
        controller_class.exception_notifier_callback = lambda do |controller, exception, req|
          controller.error_identifier = 'my-test-identifier'
        end
        get :test_error
        expect(content[:error_identifier]).to eq('my-test-identifier')
      end

      it 'should throw the correct error for invalid api versions' do
        get :echo, {}, :version => '3'
        expect(content['error']).to eq('invalid_version')
      end

      it 'should return the correct output for a manually thrown error' do
        get :demo_exception
        expect(content['error']).to eq('throttled')
        expect(content['error_description']).to be_present
      end

      it 'should stop the flow if you raise an exception' do
        get :premature_termination
        expect(content['error']).to be_present
        expect(content['error_description']).to be_present
        expect(content['response']).to be_nil
      end

      it 'should use i18n for error messages' do
        with_translations :rocket_pants => {:errors => {:throttled => 'Oh noes, a puddle.'}} do
          get :demo_exception
        end
        expect(content['error']).to eq('throttled')
        expect(content['error_description']).to eq('Oh noes, a puddle.')
      end
    end

  end

  describe 'hooking into the built in error handling' do

    let(:controller_class) do
      klass = Class.new(TestController)
      klass.class_eval do
        rescue_from StandardError, :with => :render_error
      end
      klass
    end

    let(:error) do
      TestController::ErrorOfDoom.new("Hello there")
    end

    let!(:error_mapping) { Hash.new }

    before :each do
      # Replace it with a new error mapping.
      allow(controller_class).to receive(:error_mapping) { error_mapping }
      allow_any_instance_of(controller_class).to receive(:error_mapping) { error_mapping }
      allow(controller_class).to receive(:test_error) { error }
    end

    it 'should let you hook into the error name lookup' do
      allow_any_instance_of(controller_class).to receive(:lookup_error_name).with(error).and_return(:my_test_error)
      get :test_error
      expect(content['error']).to eq('my_test_error')
    end

    it 'should let you hook into the error message lookup' do
      allow_any_instance_of(controller_class).to receive(:lookup_error_message).with(error).and_return 'Oh look, pie.'
      get :test_error
      expect(content['error_description']).to eq('Oh look, pie.')
    end

    it 'should let you hook into the error status lookup' do
      allow_any_instance_of(controller_class).to receive(:lookup_error_status).with(error).and_return 403
      get :test_error
      expect(response.status).to eq(403)
    end

    it 'should let you add error items to the response' do
      allow_any_instance_of(controller_class).to receive(:lookup_error_extras).with(error).and_return({ hello: 'There' })
      get :test_error
      expect(content['hello']).to eq('There')
    end

    it 'should default to extracting metadata from the context' do
      def error.context;  {:metadata => {:hello => 'There'}} ; end
      get :test_error
      expect(content['hello']).to eq('There')
    end

    it 'should let you pass through data via the context in the controller' do
      controller_class.send(:define_method, :demo_exception) { error! :throttled, :metadata => {:hello => "There"}}
      get :demo_exception
      expect(content['hello']).to eq('There')
    end

    it 'should let you register an item in the error mapping' do
      controller_class.error_mapping[TestController::ErrorOfDoom] = RocketPants::Throttled
      get :test_error
      expect(content['error']).to eq('throttled')
    end

    it 'should let you register a custom error mapping' do
      controller_class.error_mapping[TestController::ErrorOfDoom] = lambda do |exception|
        RocketPants::Throttled.new(exception)
      end
      get :test_error
      expect(content['error']).to eq('throttled')
    end

    it 'should let you register a custom error mapping with metadata' do
      controller_class.error_mapping[TestController::ErrorOfDoom] = lambda do |exception|
        RocketPants::Throttled.new(exception).tap do |e|
          e.context = {:metadata => {:test => true}}
        end
      end
      get :test_error
      expect(content['error']).to eq('throttled')
      expect(content['test']).to eq(true)
    end

    it 'should include parents when checking the mapping' do
      allow(controller_class).to receive(:test_error) { TestController::YetAnotherError }
      controller_class.error_mapping[TestController::ErrorOfDoom] = RocketPants::Throttled
      get :test_error
      expect(content['error']).to eq('throttled')
    end

  end

  describe 'the default exception handler' do

    let!(:error_mapping) { Hash.new }

    before :each do
      # Replace it with a new error mapping.
      allow(controller_class).to receive(:error_mapping) { error_mapping }
      allow_any_instance_of(controller_class).to receive(:error_mapping) { error_mapping }
      controller_class.use_named_exception_notifier :default
    end

    it 'should pass through the exception if pass through is enabled' do
      with_config :pass_through_errors, true do
        expect { get :test_error }.to raise_error NotImplementedError
      end
    end

    it 'should catch through the exception if pass through is disabled' do
      with_config :pass_through_errors, false do
        get :test_error
        expect(content).to have_key "error"
        expect(content).to have_key "error_description"
        expect(content[:error]).to eq("system")
      end
    end

    it 'should default to having the exception message' do
      with_config :show_exception_message, true do
        with_config :pass_through_errors, false do
          allow(controller_class).to receive(:test_error) { StandardError.new("This is a fake message.") }
          get :test_error
          expect(content[:error_description]).to be_present
          expect(content[:error_description]).to eq("This is a fake message.")
        end
      end
    end

    it 'should let you disable using the exception message' do
      with_config :show_exception_message, false do
        with_config :pass_through_errors, false do
          allow(controller_class).to receive(:test_error) { StandardError.new("This is a fake message.") }
          get :test_error
          expect(content[:error_description]).to be_present
          expect(content[:error_description]).to_not eq("This is a fake message.")
        end
      end
    end

  end

  describe 'custom exception_notifier_callback' do
    before do
      @called_exception_notifier_callback = false
    end

    let(:custom_exception_notifier_callback) {
      lambda {|c,e,r| @called_exception_notifier_callback = true }
    }

    before :each do
      # Replace it with a new error mapping.
      allow(controller_class).to receive(:error_mapping) { error_mapping }
      allow_any_instance_of(controller_class).to receive(:error_mapping) { error_mapping }
      controller_class.exception_notifier_callback = custom_exception_notifier_callback
    end

    it "should call the custom exception notifier callback" do
      with_config :pass_through_errors, false do
        get :test_error
        expect(@called_exception_notifier_callback).to be_truthy
      end
    end

  end

end
