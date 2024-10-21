# frozen_string_literal: true

RSpec.describe Service::Runner do
  class SuccessService
    include Service::Base
  end

  class FailureService
    include Service::Base

    step :fail_step

    def fail_step
      fail!("error")
    end
  end

  class FailedPolicyService
    include Service::Base

    policy :test

    def test
      false
    end
  end

  class SuccessPolicyService
    include Service::Base

    policy :test

    def test
      true
    end
  end

  class FailedContractService
    include Service::Base

    contract do
      attribute :test

      validates :test, presence: true
    end
  end

  class SuccessContractService
    include Service::Base

    contract {}
  end

  class FailureWithModelService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      nil
    end
  end

  class FailureWithOptionalModelService
    include Service::Base

    model :fake_model, optional: true

    private

    def fetch_fake_model
      nil
    end
  end

  class FailureWithModelErrorsService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      OpenStruct.new(invalid?: true)
    end
  end

  class SuccessWithModelService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      :model_found
    end
  end

  class SuccessWithModelErrorsService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      OpenStruct.new
    end
  end

  class FailureWithCollectionModelService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      []
    end
  end

  class SuccessWithCollectionModelService
    include Service::Base

    model :fake_model, :fetch_fake_model

    private

    def fetch_fake_model
      [:models_found]
    end
  end

  class RelationModelService
    include Service::Base

    model :fake_model

    private

    def fetch_fake_model
      User.where(admin: false)
    end
  end

  describe ".call" do
    subject(:runner) { described_class.call(service, dependencies, &actions_block) }

    let(:result) { object.result }
    let(:actions_block) { object.instance_eval(actions) }
    let(:service) { SuccessService }
    let(:actions) { "proc {}" }
    let(:dependencies) { { guardian: stub, params: {} } }
    let(:object) do
      Class
        .new(ApplicationController) do
          def request
            OpenStruct.new
          end
        end
        .new
    end

    it "runs the provided service in the context of a controller" do
      runner
      expect(result).to be_a Service::Base::Context
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

        context "when not using the block argument" do
          it "runs the provided block" do
            expect(runner).to eq :policy_failure
          end
        end

        context "when using the block argument" do
          let(:actions) { <<-BLOCK }
              proc do
                on_failed_policy(:test) { |policy| policy == result["result.policy.test"] }
              end
            BLOCK

          it "runs the provided block" do
            expect(runner).to be true
          end
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

        context "when not using the block argument" do
          it "runs the provided block" do
            expect(runner).to eq :contract_failure
          end
        end

        context "when using the block argument" do
          let(:actions) { <<-BLOCK }
              proc do
                on_failed_contract { |contract| contract == result["result.contract.default"] }
              end
            BLOCK

          it "runs the provided block" do
            expect(runner).to be true
          end
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
          proc do
            on_model_not_found(:fake_model) { :no_model }
          end
        BLOCK

      context "when fetching a single model" do
        context "when the service uses an optional model" do
          let(:service) { FailureWithOptionalModelService }

          it "does not run the provided block" do
            expect(runner).not_to eq :no_model
          end
        end

        context "when the service fails without a model" do
          let(:service) { FailureWithModelService }

          context "when not using the block argument" do
            it "runs the provided block" do
              expect(runner).to eq :no_model
            end
          end

          context "when using the block argument" do
            let(:actions) { <<-BLOCK }
                proc do
                  on_model_not_found(:fake_model) { |model| model == result["result.model.fake_model"] }
                end
              BLOCK

            it "runs the provided block" do
              expect(runner).to be true
            end
          end
        end

        context "when the service does not fail with a model" do
          let(:service) { SuccessWithModelService }

          it "does not run the provided block" do
            expect(runner).not_to eq :no_model
          end
        end
      end

      context "when fetching a collection" do
        context "when the service fails without a model" do
          let(:service) { FailureWithCollectionModelService }

          it "runs the provided block" do
            expect(runner).to eq :no_model
          end
        end

        context "when the service does not fail with a model" do
          let(:service) { SuccessWithCollectionModelService }

          it "does not run the provided block" do
            expect(runner).not_to eq :no_model
          end
        end
      end

      context "when fetching an ActiveRecord relation" do
        let(:service) { RelationModelService }

        context "when the service does not fail" do
          before { Fabricate(:user) }

          it "does not run the provided block" do
            expect(runner).not_to eq :no_model
          end

          it "does not fetch records from the relation" do
            runner
            expect(result[:fake_model]).not_to be_loaded
          end
        end

        context "when the service fails" do
          it "runs the provided block" do
            expect(runner).to eq :no_model
          end

          it "does not fetch records from the relation" do
            runner
            expect(result[:fake_model]).not_to be_loaded
          end
        end
      end
    end

    context "when using the on_model_errors action" do
      let(:actions) { <<-BLOCK }
          proc do
            on_model_errors(:fake_model) { :model_errors }
          end
        BLOCK

      context "when the service fails with a model containing errors" do
        let(:service) { FailureWithModelErrorsService }

        context "when not using the block argument" do
          it "runs the provided block" do
            expect(runner).to eq :model_errors
          end
        end

        context "when using the block argument" do
          let(:actions) { <<-BLOCK }
              proc do
                on_model_errors(:fake_model) { |model| model == OpenStruct.new(invalid?: true) }
              end
            BLOCK

          it "runs the provided block" do
            expect(runner).to be true
          end
        end
      end

      context "when the service does not fail with a model containing errors" do
        let(:service) { SuccessWithModelErrorsService }

        it "does not run the provided block" do
          expect(runner).not_to eq :model_errors
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
      let(:object) { Class.new(Jobs::Base).new }
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
