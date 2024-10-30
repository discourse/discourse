# frozen_string_literal: true

RSpec.describe Service::StepsInspector do
  class DummyService
    include Service::Base

    options do
      attribute :my_option, :boolean, default: true
      attribute :my_other_option, :integer, default: 1
    end

    model :model
    policy :policy
    params do
      attribute :parameter

      validates :parameter, presence: true
    end
    transaction do
      step :in_transaction_step_1
      step :in_transaction_step_2
    end
    step :final_step
  end

  subject(:inspector) { described_class.new(result) }

  let(:parameter) { "present" }
  let(:result) { DummyService.call(params: { parameter: parameter }) }

  before do
    class DummyService
      %i[fetch_model policy in_transaction_step_1 in_transaction_step_2 final_step].each do |name|
        define_method(name) { true }
      end
    end
  end

  describe "#inspect" do
    subject(:output) { inspector.inspect.strip }

    context "when service runs without error" do
      it "outputs all the steps of the service" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/8] [options] 'default' ✅
        [2/8] [model] 'model' ✅
        [3/8] [policy] 'policy' ✅
        [4/8] [params] 'default' ✅
        [5/8] [transaction]
        [6/8]   [step] 'in_transaction_step_1' ✅
        [7/8]   [step] 'in_transaction_step_2' ✅
        [8/8] [step] 'final_step' ✅
        OUTPUT
      end
    end

    context "when the model step is failing" do
      before do
        class DummyService
          def fetch_model
            false
          end
        end
      end

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/8] [options] 'default' ✅
        [2/8] [model] 'model' ❌
        [3/8] [policy] 'policy'
        [4/8] [params] 'default'
        [5/8] [transaction]
        [6/8]   [step] 'in_transaction_step_1'
        [7/8]   [step] 'in_transaction_step_2'
        [8/8] [step] 'final_step'
        OUTPUT
      end
    end

    context "when the policy step is failing" do
      before do
        class DummyService
          def policy
            false
          end
        end
      end

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/8] [options] 'default' ✅
        [2/8] [model] 'model' ✅
        [3/8] [policy] 'policy' ❌
        [4/8] [params] 'default'
        [5/8] [transaction]
        [6/8]   [step] 'in_transaction_step_1'
        [7/8]   [step] 'in_transaction_step_2'
        [8/8] [step] 'final_step'
        OUTPUT
      end
    end

    context "when the params step is failing" do
      let(:parameter) { nil }

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/8] [options] 'default' ✅
        [2/8] [model] 'model' ✅
        [3/8] [policy] 'policy' ✅
        [4/8] [params] 'default' ❌
        [5/8] [transaction]
        [6/8]   [step] 'in_transaction_step_1'
        [7/8]   [step] 'in_transaction_step_2'
        [8/8] [step] 'final_step'
        OUTPUT
      end
    end

    context "when a common step is failing" do
      before do
        class DummyService
          def in_transaction_step_2
            fail!("step error")
          end
        end
      end

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/8] [options] 'default' ✅
        [2/8] [model] 'model' ✅
        [3/8] [policy] 'policy' ✅
        [4/8] [params] 'default' ✅
        [5/8] [transaction]
        [6/8]   [step] 'in_transaction_step_1' ✅
        [7/8]   [step] 'in_transaction_step_2' ❌
        [8/8] [step] 'final_step'
        OUTPUT
      end
    end

    context "when running in specs" do
      context "when a successful step is flagged as being an unexpected result" do
        before { result["result.policy.policy"]["spec.unexpected_result"] = true }

        it "adapts its output accordingly" do
          expect(output).to eq <<~OUTPUT.chomp
          [1/8] [options] 'default' ✅
          [2/8] [model] 'model' ✅
          [3/8] [policy] 'policy' ✅ ⚠️  <= expected to return false but got true instead
          [4/8] [params] 'default' ✅
          [5/8] [transaction]
          [6/8]   [step] 'in_transaction_step_1' ✅
          [7/8]   [step] 'in_transaction_step_2' ✅
          [8/8] [step] 'final_step' ✅
          OUTPUT
        end
      end

      context "when a failing step is flagged as being an unexpected result" do
        before do
          class DummyService
            def policy
              false
            end
          end
          result["result.policy.policy"]["spec.unexpected_result"] = true
        end

        it "adapts its output accordingly" do
          expect(output).to eq <<~OUTPUT.chomp
          [1/8] [options] 'default' ✅
          [2/8] [model] 'model' ✅
          [3/8] [policy] 'policy' ❌ ⚠️  <= expected to return true but got false instead
          [4/8] [params] 'default'
          [5/8] [transaction]
          [6/8]   [step] 'in_transaction_step_1'
          [7/8]   [step] 'in_transaction_step_2'
          [8/8] [step] 'final_step'
          OUTPUT
        end
      end
    end
  end

  describe "#error" do
    subject(:error) { inspector.error }

    context "when there are no errors" do
      it "returns nothing" do
        expect(error).to be_blank
      end
    end

    context "when the model step is failing" do
      context "when the model is missing" do
        before do
          class DummyService
            def fetch_model
              false
            end
          end
        end

        it "returns an error related to the model" do
          expect(error).to match(/Model not found/)
        end
      end

      context "when the model has errors" do
        before do
          class DummyService
            def fetch_model
              OpenStruct.new(invalid?: true, errors: ActiveModel::Errors.new(nil))
            end
          end
        end

        it "returns an error related to the model" do
          expect(error).to match(/ActiveModel::Errors \[\]/)
        end
      end
    end

    context "when the params step is failing" do
      let(:parameter) { nil }

      it "returns an error related to the contract" do
        expect(error).to match(/ActiveModel::Error attribute=parameter, type=blank, options={}/)
      end

      it "returns the provided paramaters" do
        expect(error).to match(/{"parameter"=>nil}/)
      end
    end

    context "when the policy step is failing" do
      before do
        class DummyService
          def policy
            false
          end
        end
      end

      context "when there is no reason provided" do
        it "returns nothing" do
          expect(error).to be_blank
        end
      end

      context "when a reason is provided" do
        before { result["result.policy.policy"][:reason] = "failed" }

        it "returns the reason" do
          expect(error).to eq "failed"
        end
      end
    end

    context "when a common step is failing" do
      before { result["result.step.final_step"].fail(error: "my error") }

      it "returns an error related to the step" do
        expect(error).to eq("my error")
      end
    end
  end
end
