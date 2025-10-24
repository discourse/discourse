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
      attribute :other_param, :integer

      validates :parameter, presence: true
    end

    lock(:parameter, :other_param) do
      transaction do
        step :in_transaction_step_1
        step :in_transaction_step_2
      end
    end

    try { step :might_raise }
    only_if(:condition) { step :optional_step }
    step :final_step
  end

  subject(:inspector) { described_class.new(result) }

  let(:parameter) { "present" }
  let(:result) { DummyService.call(params: { parameter: }) }

  before do
    class DummyService
      %i[
        fetch_model
        policy
        in_transaction_step_1
        in_transaction_step_2
        might_raise
        condition
        optional_step
        final_step
      ].each { |name| define_method(name) { true } }
    end
  end

  describe "#execution_flow" do
    subject(:output) do
      inspector.execution_flow.strip.gsub(%r{ \(\d+\.\d+ ms\)}, "").gsub(/\e\[\d+(;\d+)?m/, "")
    end

    context "when service runs without error" do
      it "outputs all the steps of the service" do
        expect(output).to eq <<~OUTPUT.chomp
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ✅
        [ 5/13] [lock] parameter:other_param ✅
        [ 6/13]   [transaction]
        [ 7/13]     [step] in_transaction_step_1 ✅
        [ 8/13]     [step] in_transaction_step_2 ✅
        [ 9/13] [try]
        [10/13]   [step] might_raise ✅
        [11/13] [only_if] condition ✅
        [12/13]   [step] optional_step ✅
        [13/13] [step] final_step ✅
        OUTPUT
      end

      it "outputs time taken by each step" do
        expect(inspector.execution_flow).to match(/\d+\.\d+ ms/)
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
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ❌

        (11 more steps not shown as the execution flow was stopped before reaching them)
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
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ❌

        (10 more steps not shown as the execution flow was stopped before reaching them)
        OUTPUT
      end
    end

    context "when the params step is failing" do
      let(:parameter) { nil }

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ❌

        (9 more steps not shown as the execution flow was stopped before reaching them)
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
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ✅
        [ 5/13] [lock] parameter:other_param ✅
        [ 6/13]   [transaction]
        [ 7/13]     [step] in_transaction_step_1 ✅
        [ 8/13]     [step] in_transaction_step_2 ❌

        (5 more steps not shown as the execution flow was stopped before reaching them)
        OUTPUT
      end
    end

    context "when a step raises an exception inside the 'try' block" do
      before do
        class DummyService
          def might_raise
            raise "BOOM"
          end
        end
      end

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ✅
        [ 5/13] [lock] parameter:other_param ✅
        [ 6/13]   [transaction]
        [ 7/13]     [step] in_transaction_step_1 ✅
        [ 8/13]     [step] in_transaction_step_2 ✅
        [ 9/13] [try]
        [10/13]   [step] might_raise 💥

        (3 more steps not shown as the execution flow was stopped before reaching them)
        OUTPUT
      end
    end

    context "when the lock step is failing" do
      before { allow(DistributedMutex).to receive(:synchronize) }

      it "shows the failing step" do
        expect(output).to eq <<~OUTPUT.chomp
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ✅
        [ 5/13] [lock] parameter:other_param ❌

        (8 more steps not shown as the execution flow was stopped before reaching them)
        OUTPUT
      end
    end

    context "when the only_if step condition is not met" do
      before do
        class DummyService
          def condition
            false
          end
        end
      end

      it "shows the block was skipped" do
        expect(output).to eq <<~OUTPUT.chomp
        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ✅
        [ 5/13] [lock] parameter:other_param ✅
        [ 6/13]   [transaction]
        [ 7/13]     [step] in_transaction_step_1 ✅
        [ 8/13]     [step] in_transaction_step_2 ✅
        [ 9/13] [try]
        [10/13]   [step] might_raise ✅
        [11/13] [only_if] condition ⏭️ (condition was not met)
        [12/13]   [step] optional_step
        [13/13] [step] final_step ✅
        OUTPUT
      end
    end

    context "when running in specs" do
      context "when a successful step is flagged as being an unexpected result" do
        before { result["result.policy.policy"]["spec.unexpected_result"] = true }

        it "adapts its output accordingly" do
          expect(output).to eq <<~OUTPUT.chomp
          [ 1/13] [options] default ✅
          [ 2/13] [model] model ✅
          [ 3/13] [policy] policy ✅ ⚠️  <= expected to return false but got true instead
          [ 4/13] [params] default ✅
          [ 5/13] [lock] parameter:other_param ✅
          [ 6/13]   [transaction]
          [ 7/13]     [step] in_transaction_step_1 ✅
          [ 8/13]     [step] in_transaction_step_2 ✅
          [ 9/13] [try]
          [10/13]   [step] might_raise ✅
          [11/13] [only_if] condition ✅
          [12/13]   [step] optional_step ✅
          [13/13] [step] final_step ✅
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
          [ 1/13] [options] default ✅
          [ 2/13] [model] model ✅
          [ 3/13] [policy] policy ❌ ⚠️  <= expected to return true but got false instead

          (10 more steps not shown as the execution flow was stopped before reaching them)
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

      context "when an exception occurs inside the model step" do
        before do
          class DummyService
            def fetch_model
              raise "BOOM"
            end
          end
        end

        it "returns an error related to the exception" do
          expect(error).to match(/BOOM \([^(]*RuntimeError[^)]*\)/)
        end
      end

      context "when the model has errors" do
        before do
          class DummyService
            def fetch_model
              OpenStruct.new(
                has_changes_to_save?: true,
                invalid?: true,
                errors: ActiveModel::Errors.new(nil),
              )
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
        # first option is for ruby 3.3 and the other for 3.4
        expect(error).to match(/{"parameter"=>nil, "other_param"=>nil}/).or match(
               /{"parameter" => nil, "other_param" => nil}/,
             )
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

    context "when an exception occurred inside the 'try' block" do
      before do
        class DummyService
          def might_raise
            raise "BOOM"
          end
        end
      end

      it "returns an error related to the exception" do
        expect(error).to match(/BOOM \([^(]*RuntimeError[^)]*\)/)
      end
    end

    context "when the lock step is failing" do
      before { allow(DistributedMutex).to receive(:synchronize) }

      it "returns an error" do
        expect(error).to eq("Lock 'parameter:other_param' was not acquired.")
      end
    end
  end

  describe "#inspect" do
    let(:parameter) { nil }

    it "outputs the service class name, the steps results and the specific error" do
      # first option is for ruby 3.3 and the other for 3.4
      # the only difference between them is in the last line where the hash
      # arrows are surrounded with spaces
      expect(inspector.inspect.gsub(%r{ \(\d+\.\d+ ms\)}, "").gsub(/\e\[\d+(;\d+)?m/, "")).to eq(
        <<~OUTPUT,
        Inspecting DummyService result object:

        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ❌

        (9 more steps not shown as the execution flow was stopped before reaching them)

        Why it failed:

        #<ActiveModel::Errors [#<ActiveModel::Error attribute=parameter, type=blank, options={}>]>

        Provided parameters: {"parameter"=>nil, "other_param"=>nil}
      OUTPUT
      ).or eq(<<~OUTPUT)
        Inspecting DummyService result object:

        [ 1/13] [options] default ✅
        [ 2/13] [model] model ✅
        [ 3/13] [policy] policy ✅
        [ 4/13] [params] default ❌

        (9 more steps not shown as the execution flow was stopped before reaching them)

        Why it failed:

        #<ActiveModel::Errors [#<ActiveModel::Error attribute=parameter, type=blank, options={}>]>

        Provided parameters: {"parameter" => nil, "other_param" => nil}
        OUTPUT
    end
  end
end
