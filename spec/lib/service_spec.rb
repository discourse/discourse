# frozen_string_literal: true

RSpec.describe Service do
  let(:service_class) { Class.new { include Service::Base } }

  describe "Steps" do
    describe "Model step" do
      context "when providing default values to step implementation" do
        before do
          service_class.class_eval do
            model :my_model

            def fetch_my_model(default_arg: 2)
              true
            end
          end
        end

        it "raises an error" do
          expect { service_class.call }.to raise_error(/In model 'my_model': default values/)
        end
      end
    end

    describe "Policy step" do
      context "when providing default values to step implementation" do
        before do
          service_class.class_eval do
            policy :my_policy

            def my_policy(default_arg: 2)
              true
            end
          end
        end

        it "raises an error" do
          expect { service_class.call }.to raise_error(/In policy 'my_policy': default values/)
        end
      end

      context "when providing a class which delegates its `#call` method" do
        before do
          service_class.class_eval do
            class MyPolicy < Service::PolicyBase
              class MyStrategy
                def call
                end

                def reason
                end
              end

              attr_reader :strategy

              delegate :call, :reason, to: :strategy

              def initialize(*)
                @strategy = MyStrategy.new
              end
            end

            policy :my_policy, class_name: MyPolicy
          end
        end

        it "does not raise an error" do
          expect { service_class.call }.not_to raise_error
        end
      end
    end

    describe "Generic step" do
      context "when providing default values to step implementation" do
        before do
          service_class.class_eval do
            step :generic_step

            def generic_step(default_arg: 2)
              true
            end
          end
        end

        it "raises an error" do
          expect { service_class.call }.to raise_error(/In step 'generic_step': default values/)
        end
      end
    end
  end

  describe "Parameters handling" do
    subject(:result) { service_class.call(**args) }

    context "when calling the service without any params" do
      let(:args) { {} }

      it "instantiate a default params object" do
        expect(result[:params]).not_to be_nil
      end
    end

    context "when calling the service with params" do
      let(:args) { { params: { param1: "one" } } }

      context "when there is no `params` step defined" do
        it "allows accessing `params` through methods" do
          expect(result[:params].param1).to eq("one")
        end

        it "returns nothing for a non-existent key" do
          expect(result[:params].non_existent_key).to be_nil
        end
      end

      context "when there is a `params` step defined" do
        before { service_class.class_eval { params { attribute :param1 } } }

        it "returns the contract as the params object" do
          expect(result[:params]).to be_a(Service::ContractBase)
        end
      end
    end
  end

  describe "Thread safety" do
    context "when services are run concurrently" do
      let(:service) do
        Class.new do
          include Service::Base

          policy :limit_reached
          step :update

          def limit_reached
            $redis.get("my_counter").to_i < 3
          end

          def update
            $redis.incr("my_counter")
          end
        end
      end

      it "works properly" do
        # When not thread-safe, a failed service can hold the wrong context,
        # which raises an exception
        expect { 10.times.map { Thread.new { service.call } }.map(&:join) }.not_to raise_error
      end
    end
  end
end
