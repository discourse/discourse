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

  describe "Contract" do
    subject(:result) { service_class.call(**args) }

    let(:args) { { params: {} } }

    describe "Reusability" do
      before do
        another_contract =
          Class.new(Service::ContractBase) do
            attribute :id

            validates :id, presence: true
          end
        service_class.class_eval { params base_class: another_contract }
      end

      it "executes another contract" do
        expect(result.params).to be_invalid
        expect(result.params.errors.details).to match({ id: [{ error: :blank }] })
      end
    end

    describe "Using values from a model" do
      let(:args) { super().merge(params:, stored_model:) }
      let(:params) { {} }
      let(:stored_model) { defaults }
      let(:defaults) { { id: 1, name: "John" } }

      before do
        service_class.class_eval do
          model

          params(default_values_from: :model) do
            attribute :id, :integer
            attribute :name, :string
            attribute :groups, :array, default: -> { [] }
          end

          def fetch_model(stored_model:)
            stored_model
          end
        end
      end

      context "when the model has nested attributes" do
        let(:params) { super().merge(dimensions: { width: 800, crop: { x: 10 } }) }
        let(:defaults) do
          super().merge(
            caption: "Original",
            enabled: true,
            dimensions: {
              "width" => 640,
              "height" => 480,
              "crop" => {
                "x" => 20,
                "y" => 30,
              },
            },
            layers: [{ "width" => 100, "height" => 200 }],
          )
        end

        before do
          service_class::Contract.class_eval do
            attribute :caption, :string
            attribute :enabled, :boolean

            attribute :dimensions, :hash do
              attribute :width, :integer
              attribute :height, :integer

              attribute :crop, :hash do
                attribute :x, :integer
                attribute :y, :integer
              end

              validates :width, :height, presence: true
            end

            attribute :layers, :array do
              attribute :width, :integer
              attribute :height, :integer
            end

            validates :dimensions, presence: true
          end
        end

        context "when nested values are omitted" do
          it "fills omitted keys at each level" do
            expect(result.params.dimensions.to_hash).to eq(
              width: 800,
              height: 480,
              crop: {
                x: 10,
                y: 30,
              },
            )
          end

          it "validates the completed input" do
            expect(result).to run_successfully
          end

          it "preserves an omitted array" do
            expect(result.params.to_hash[:layers]).to eq([{ width: 100, height: 200 }])
          end

          it "leaves the model defaults unchanged" do
            expect { result }.not_to change { defaults.deep_dup }
          end
        end

        context "when the input has string keys" do
          let(:params) { { "dimensions" => { "width" => 800, "crop" => { "x" => 10 } } } }

          it "leaves the supplied input unchanged" do
            expect { result }.not_to change { params.deep_dup }
          end

          it "combines string and symbol keys" do
            expect(result.params.dimensions.to_hash).to eq(
              width: 800,
              height: 480,
              crop: {
                x: 10,
                y: 30,
              },
            )
          end
        end

        context "when the model exposes its attributes" do
          let(:stored_model) { Struct.new(:attributes).new(defaults) }

          it "fills omitted keys from model attributes" do
            expect(result.params.dimensions.to_hash).to eq(
              width: 800,
              height: 480,
              crop: {
                x: 10,
                y: 30,
              },
            )
          end
        end

        context "when an empty hash is supplied" do
          let(:params) { { dimensions: {} } }

          it "preserves the nested defaults" do
            expect(result.params.dimensions.to_hash).to eq(
              width: 640,
              height: 480,
              crop: {
                x: 20,
                y: 30,
              },
            )
          end
        end

        context "when explicit nil and falsy values are supplied" do
          let(:params) { { caption: nil, enabled: false, dimensions: { width: 0 } } }

          it "uses the supplied values" do
            expect(result.params.to_hash).to include(
              caption: nil,
              enabled: false,
              dimensions: {
                width: 0,
                height: 480,
                crop: {
                  x: 20,
                  y: 30,
                },
              },
            )
          end
        end

        context "when a nested hash is explicitly cleared" do
          let(:params) { { dimensions: nil } }

          it "keeps the supplied nil" do
            expect(result.params.dimensions).to be_nil
          end

          it "validates the supplied nil" do
            expect(result).to fail_a_contract
          end
        end

        context "when a nested hash has an invalid shape" do
          let(:params) { { dimensions: "invalid" } }

          it "rejects the input" do
            expect(result).to fail_a_contract
          end
        end

        context "when an array is supplied" do
          let(:params) { { layers: [{ width: 300 }] } }

          it "replaces the array without inheriting elements or their fields" do
            expect(result.params.to_hash[:layers]).to eq([{ width: 300, height: nil }])
          end
        end

        context "when an empty array is supplied" do
          let(:params) { { layers: [] } }

          it "clears the array" do
            expect(result.params.layers).to be_empty
          end
        end

        context "when a named contract follows the default contract" do
          before do
            service_class.class_eval do
              params(:resize) do
                attribute :dimensions, :hash do
                  attribute :width, :integer
                  attribute :height, :integer
                end
              end
            end
          end

          it "passes the completed parameters to the named contract" do
            expect(result.resize_contract.dimensions.to_hash).to eq(width: 800, height: 480)
          end
        end
      end

      it "applies values from a model to the contract attributes" do
        expect(result.params).to have_attributes(id: 1, name: "John", groups: [])
      end
    end
  end
end
