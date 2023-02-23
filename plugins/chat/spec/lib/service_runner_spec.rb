# frozen_string_literal: true

RSpec.describe Chat::ServiceRunner do
  class SuccessService
    include Chat::Service::Base
  end

  class FailureService
    include Chat::Service::Base

    step :fail_step

    def fail_step
      fail!("error")
    end
  end

  class FailedPolicyService
    include Chat::Service::Base

    policy :test

    def test
      false
    end
  end

  class SuccessPolicyService
    include Chat::Service::Base

    policy :test

    def test
      true
    end
  end

  class FailedContractService
    include Chat::Service::Base

    class Contract
      attribute :test
      validates :test, presence: true
    end

    contract
  end

  class SuccessContractService
    include Chat::Service::Base

    contract
  end

  class FailureWithModelService
    include Chat::Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      nil
    end
  end

  class SuccessWithModelService
    include Chat::Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      :model_found
    end
  end

  describe ".call(service, &block)" do
    subject(:runner) { described_class.call(service, object, &actions_block) }

    let(:result) { object.result }
    let(:actions_block) { object.instance_eval(actions) }
    let(:service) { SuccessService }
    let(:actions) { "proc {}" }
    let(:object) do
      Class
        .new(Chat::Api) do
          def request
            OpenStruct.new
          end

          def params
            ActionController::Parameters.new
          end

          def guardian
          end
        end
        .new
    end

    it "runs the provided service in the context of a controller" do
      runner
      expect(result).to be_a Chat::Service::Base::Context
      expect(result).to be_a_success
    end

    context "when using the on_success action" do
      let(:actions) { <<-BLOCK }
          proc do
            on_success { :success }
          end
        BLOCK

      context "when the service succeeds" do
        it "runs the provided block" do
          expect(runner).to eq :success
        end
      end

      context "when the service does not succeed" do
        let(:service) { FailureService }

        it "does not run the provided block" do
          expect(runner).not_to eq :success
        end
      end
    end

    context "when using the on_failure action" do
      let(:actions) { <<-BLOCK }
          proc do
            on_failure { :fail }
          end
        BLOCK

      context "when the service fails" do
        let(:service) { FailureService }

        it "runs the provided block" do
          expect(runner).to eq :fail
        end
      end

      context "when the service does not fail" do
        let(:service) { SuccessService }

        it "does not run the provided block" do
          expect(runner).not_to eq :fail
        end
      end
    end

    context "when using the on_failed_policy action" do
      let(:actions) { <<-BLOCK }
          proc do
            on_failed_policy(:test) { :policy_failure }
          end
        BLOCK

      context "when the service policy fails" do
        let(:service) { FailedPolicyService }

        it "runs the provided block" do
          expect(runner).to eq :policy_failure
        end
      end

      context "when the service policy does not fail" do
        let(:service) { SuccessPolicyService }

        it "does not run the provided block" do
          expect(runner).not_to eq :policy_failure
        end
      end
    end

    context "when using the on_failed_contract action" do
      let(:actions) { <<-BLOCK }
          proc do
            on_failed_contract { :contract_failure }
          end
        BLOCK

      context "when the service contract fails" do
        let(:service) { FailedContractService }

        it "runs the provided block" do
          expect(runner).to eq :contract_failure
        end
      end

      context "when the service contract does not fail" do
        let(:service) { SuccessContractService }

        it "does not run the provided block" do
          expect(runner).not_to eq :contract_failure
        end
      end
    end

    context "when using the on_model_not_found action" do
      let(:actions) { <<-BLOCK }
          ->(*) do
            on_model_not_found(:fake_model) { :no_model }
          end
        BLOCK

      context "when the service failed without a model" do
        let(:service) { FailureWithModelService }

        it "runs the provided block" do
          expect(runner).to eq :no_model
        end
      end

      context "when the service does not fail with a model" do
        let(:service) { SuccessWithModelService }

        it "does not run the provided block" do
          expect(runner).not_to eq :no_model
        end
      end
    end

    context "when using several actions together" do
      let(:service) { FailureService }
      let(:actions) { <<-BLOCK }
          proc do
            on_success { :success }
            on_failure { :failure }
            on_failed_policy { :policy_failure }
          end
        BLOCK

      it "runs the first matching action" do
        expect(runner).to eq :failure
      end
    end

    context "when running in the context of a job" do
      let(:object) { Class.new(ServiceJob).new }
      let(:actions) { <<-BLOCK }
          proc do
            on_success { :success }
            on_failure { :failure }
          end
        BLOCK

      it "runs properly" do
        expect(runner).to eq :success
      end
    end
  end
end
