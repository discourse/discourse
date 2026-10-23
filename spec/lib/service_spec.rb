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

    describe "Resource imports" do
      let(:resource_class) do
        Class.new(JsonApiKit::Resource) do
          attribute :title, :string, writable: true
          attribute :priority, :integer, writable: true
          attribute :tags, :array, writable: true
          attribute :created_at, :datetime
        end
      end
      let(:options) { { from_resource: resource_class } }

      context "when no block is supplied" do
        subject(:declaration) { service_class.params(**options) }

        let(:attribute_names) do
          declaration
          service_class::Contract.attribute_names
        end
        let(:title_type) { resource_class.writable_attributes.first.type }
        let(:imported_title_type) do
          declaration
          service_class::Contract.attribute_types.fetch("title")
        end

        context "when only selects writable attributes" do
          let(:options) { super().merge(only: %i[title tags]) }

          it "imports the selected attributes" do
            expect(attribute_names).to contain_exactly("title", "tags")
          end
        end

        context "when except excludes writable attributes" do
          let(:options) { super().merge(except: ["priority"]) }

          it "imports the remaining attributes" do
            expect(attribute_names).to contain_exactly("title", "tags")
          end
        end

        context "when only selects no attributes" do
          let(:options) { super().merge(only: []) }

          it "imports no attributes" do
            expect(attribute_names).to be_empty
          end
        end

        context "when only and except are both supplied" do
          let(:options) { super().merge(only: [:title], except: [:priority]) }

          it "rejects the selection" do
            expect { declaration }.to raise_error(ArgumentError, /only.*except.*together/i)
          end
        end

        context "when only selects an unknown attribute" do
          let(:options) { super().merge(only: [:missing]) }

          it "identifies the invalid attribute" do
            expect { declaration }.to raise_error(ArgumentError, /missing.*writable/i)
          end
        end

        context "when only selects a read-only attribute" do
          let(:options) { super().merge(only: [:created_at]) }

          it "identifies the invalid attribute" do
            expect { declaration }.to raise_error(ArgumentError, /created_at.*writable/i)
          end
        end

        context "when except excludes an unknown attribute" do
          let(:options) { super().merge(except: [:missing]) }

          it "identifies the invalid attribute" do
            expect { declaration }.to raise_error(ArgumentError, /missing.*writable/i)
          end
        end

        context "when except excludes a read-only attribute" do
          let(:options) { super().merge(except: [:created_at]) }

          it "identifies the invalid attribute" do
            expect { declaration }.to raise_error(ArgumentError, /created_at.*writable/i)
          end
        end

        context "when only is supplied without a resource" do
          let(:options) { super().except(:from_resource).merge(only: [:title]) }

          it "requires a resource" do
            expect { declaration }.to raise_error(ArgumentError, /only.*requires.*from_resource/i)
          end
        end

        context "when except is supplied without a resource" do
          let(:options) { super().except(:from_resource).merge(except: [:title]) }

          it "requires a resource" do
            expect { declaration }.to raise_error(ArgumentError, /except.*requires.*from_resource/i)
          end
        end

        it "imports every writable attribute" do
          expect(attribute_names).to contain_exactly("title", "priority", "tags")
        end

        it "uses the resource's resolved type" do
          expect(imported_title_type).to equal(title_type)
        end
      end

      context "when a block is supplied" do
        let(:args) { super().merge(params:, **dependencies) }
        let(:params) do
          { title: "A title", priority: "2", tags: "ruby", notify: "1", created_at: "2026-10-14" }
        end
        let(:dependencies) { {} }
        let(:contract_name) { :default }
        let(:title_type) { nil }

        before do
          type = title_type
          service_class.params(contract_name, **options) do
            attribute :title, type, default: "Untitled"
            attribute :notify, :boolean, default: false

            validates :title, presence: true
          end
        end

        context "when an imported attribute fails inline validation" do
          let(:params) { super().merge(title: "") }

          it "rejects invalid imported values" do
            expect(result).to fail_a_contract
          end
        end

        context "when an inline declaration supplies a type" do
          let(:title_type) { :integer }
          let(:params) { super().merge(title: "42") }

          it "uses the inline type" do
            expect(result.params.title).to eq(42)
          end
        end

        context "when an inline declaration supplies only a default" do
          let(:params) { super().except(:title) }

          it "uses the inline default" do
            expect(result.params.title).to eq("Untitled")
          end
        end

        context "when an inline declaration omits the type" do
          let(:params) { super().merge(title: 123) }

          it "preserves the imported type" do
            expect(result.params.title).to eq("123")
          end
        end

        context "when only selects imported attributes" do
          let(:options) { super().merge(only: [:priority]) }

          it "preserves inline attributes outside the selection" do
            expect(result.params.to_hash).to eq(title: "A title", priority: 2, notify: true)
          end
        end

        context "when except excludes an inline attribute" do
          let(:options) { super().merge(except: [:title]) }

          it "preserves the inline declaration" do
            expect(result.params.title).to eq("A title")
          end
        end

        context "when a base contract is supplied" do
          let(:options) { super().merge(base_class: base_contract) }
          let(:base_contract) do
            Class.new(Service::ContractBase) { attribute :author_id, :integer, default: 7 }
          end

          it "combines inherited and imported attributes" do
            expect(result.params.to_hash).to eq(
              author_id: 7,
              title: "A title",
              priority: 2,
              tags: ["ruby"],
              notify: true,
            )
          end
        end

        context "when a model supplies default values" do
          let(:options) { super().merge(default_values_from: :post) }
          let(:params) { super().except(:priority) }
          let(:dependencies) { super().merge(post: { title: "Original", priority: "3" }) }

          it "combines model defaults with supplied values" do
            expect(result.params.to_hash).to eq(
              title: "A title",
              priority: 3,
              tags: ["ruby"],
              notify: true,
            )
          end
        end

        context "when the contract has a name" do
          let(:contract_name) { :post }

          it "exposes the imported values through the named contract" do
            expect(result.post_contract.to_hash).to eq(
              title: "A title",
              priority: 2,
              tags: ["ruby"],
              notify: true,
            )
          end
        end

        it "runs with ordinary parameters" do
          expect(result).to run_successfully
        end

        it "coerces writable attributes and inline parameters" do
          expect(result.params.to_hash).to eq(
            title: "A title",
            priority: 2,
            tags: ["ruby"],
            notify: true,
          )
        end
      end
    end

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
