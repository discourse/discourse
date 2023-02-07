# frozen_string_literal: true

RSpec.describe Chat::StepsInspector do
  class DummyService
    include Chat::Service::Base

    model :model
    policy :policy
    contract
    transaction do
      step :in_transaction_step_1
      step :in_transaction_step_2
    end
    step :final_step
  end

  subject(:inspector) { described_class.new(result) }

  let(:result) { DummyService.call }

  before do
    class DummyService
      %i[fetch_model policy in_transaction_step_1 in_transaction_step_2 final_step].each do |name|
        define_method(name) { true }
      end
    end
  end

  describe "#inspect" do
    subject(:output) { inspector.inspect }

    context "when service runs without error" do
      it "outputs all the steps of the service" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/7] [model] 'model' ✅
        [2/7] [policy] 'policy' ✅
        [3/7] [contract] 'default' ✅
        [4/7] [transaction]
        [5/7]   [step] 'in_transaction_step_1' 
        [6/7]   [step] 'in_transaction_step_2' 
        [7/7] [step] 'final_step' 
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
        [1/7] [model] 'model' ❌
        [2/7] [policy] 'policy' 
        [3/7] [contract] 'default' 
        [4/7] [transaction]
        [5/7]   [step] 'in_transaction_step_1' 
        [6/7]   [step] 'in_transaction_step_2' 
        [7/7] [step] 'final_step' 
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
        [1/7] [model] 'model' ✅
        [2/7] [policy] 'policy' ❌
        [3/7] [contract] 'default' 
        [4/7] [transaction]
        [5/7]   [step] 'in_transaction_step_1' 
        [6/7]   [step] 'in_transaction_step_2' 
        [7/7] [step] 'final_step' 
        OUTPUT
      end
    end

    context "when the contract step is failing" do
      before { result["result.contract.default"].fail }

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [1/7] [model] 'model' ✅
        [2/7] [policy] 'policy' ✅
        [3/7] [contract] 'default' ❌
        [4/7] [transaction]
        [5/7]   [step] 'in_transaction_step_1' 
        [6/7]   [step] 'in_transaction_step_2' 
        [7/7] [step] 'final_step' 
        OUTPUT
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

    context "when the contract step is failing" do
      let(:errors) { DummyService::Contract.new.errors }

      before do
        errors.add(:base, :presence)
        result["result.contract.default"].fail(errors: errors)
      end

      it "returns an error related to the contract" do
        expect(error).to match(/ActiveModel::Error attribute=base, type=presence, options={}/)
      end
    end
  end
end
