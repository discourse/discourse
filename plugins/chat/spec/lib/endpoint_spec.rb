# frozen_string_literal: true

RSpec.describe Chat::Endpoint do
  class SuccessService
    include Chat::Service::Base

    service {}
  end

  class FailureService
    include Chat::Service::Base

    service { context.fail! }
  end

  class FailedPolicyService
    include Chat::Service::Base

    policy(:test) { false }

    service {}
  end

  class SuccessPolicyService
    include Chat::Service::Base

    policy(:test) { true }

    service {}
  end

  class FailedContractService
    include Chat::Service::Base

    contract do
      attribute :test
      validates :test, presence: true
    end

    service {}
  end

  class SuccessContractService
    include Chat::Service::Base

    contract {}

    service {}
  end

  describe ".call(service, &block)" do
    subject(:endpoint) { described_class.call(service, &actions_block) }

    let(:result) { controller.result }
    let(:actions_block) { controller.instance_eval(actions) }
    let(:service) { SuccessService }
    let(:actions) { "proc {}" }
    let(:controller) do
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
      endpoint
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
          expect(endpoint).to eq :success
        end
      end

      context "when the service does not succeed" do
        let(:service) { FailureService }

        it "does not run the provided block" do
          expect(endpoint).not_to eq :success
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
          expect(endpoint).to eq :fail
        end
      end

      context "when the service does not fail" do
        let(:service) { SuccessService }

        it "does not run the provided block" do
          expect(endpoint).not_to eq :fail
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
          expect(endpoint).to eq :policy_failure
        end
      end

      context "when the service policy does not fail" do
        let(:service) { SuccessPolicyService }

        it "does not run the provided block" do
          expect(endpoint).not_to eq :policy_failure
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
          expect(endpoint).to eq :contract_failure
        end
      end

      context "when the service contract does not fail" do
        let(:service) { SuccessContractService }

        it "does not run the provided block" do
          expect(endpoint).not_to eq :contract_failure
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
        expect(endpoint).to eq :failure
      end
    end
  end
end
