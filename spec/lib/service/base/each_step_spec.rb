# frozen_string_literal: true

RSpec.describe Service::Base::EachStep do
  describe "#call" do
    subject(:result) { service.call(dependencies) }

    let(:dependencies) { {} }

    context "with basic iteration" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            step :process_user
          end

          step :finalize

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, index:)
            context[:processed] ||= []
            context[:processed] << { user:, index: }
          end

          def finalize
            context[:finalized] = true
          end
        end
      end
      let(:dependencies) { { input_users: users } }

      context "when collection has items" do
        let(:users) { %i[alice bob charlie] }

        it "iterates over each item" do
          expect(result[:processed].map { _1[:user] }).to eq(%i[alice bob charlie])
        end

        it "provides the index to each iteration" do
          expect(result[:processed].map { _1[:index] }).to eq([0, 1, 2])
        end

        it "continues to subsequent steps after iteration" do
          expect(result[:finalized]).to be true
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end
    end

    context "with empty collection (optional model)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users, optional: true

          each :users do
            step :process_user
          end

          step :finalize

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, index:)
            context[:processed] ||= []
            context[:processed] << { user:, index: }
          end

          def finalize
            context[:finalized] = true
          end
        end
      end
      let(:dependencies) { { input_users: users } }

      context "when collection is empty" do
        let(:users) { [] }

        it "skips the iteration silently" do
          expect(result[:processed]).to be_nil
        end

        it "continues to subsequent steps" do
          expect(result[:finalized]).to be true
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end

      context "when collection is nil" do
        let(:users) { nil }

        it "skips the iteration silently" do
          expect(result[:processed]).to be_nil
        end

        it "continues to subsequent steps" do
          expect(result[:finalized]).to be true
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end
    end

    context "with custom item name (as: option)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, as: :member do
            step :process_member
          end

          private

          def fetch_users
            context[:input_users]
          end

          def process_member(member:, index:)
            context[:processed] ||= []
            context[:processed] << { member:, index: }
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "uses the custom name for the item" do
        expect(result[:processed].map { _1[:member] }).to eq(%i[alice bob])
      end

      it "still provides the index" do
        expect(result[:processed].map { _1[:index] }).to eq([0, 1])
      end
    end

    context "with fail-fast on policy failure" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            policy :can_process
            step :process_user
          end

          private

          def fetch_users
            context[:input_users]
          end

          def can_process(user:)
            user != :forbidden
          end

          def process_user(user:, index:)
            context[:processed] ||= []
            context[:processed] << user
          end
        end
      end
      let(:dependencies) { { input_users: users } }

      context "when all items pass the policy" do
        let(:users) { %i[alice bob charlie] }

        it "processes all items" do
          expect(result[:processed]).to eq(%i[alice bob charlie])
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end

      context "when an item fails the policy" do
        let(:users) { %i[alice forbidden charlie] }

        it "stops iteration at the failing item" do
          expect(result[:processed]).to eq(%i[alice])
        end

        it "fails the service" do
          expect(result).to be_failure
        end

        it "stores the failing item in context" do
          expect(result[:user]).to eq(:forbidden)
        end

        it "stores the failing index in context" do
          expect(result[:index]).to eq(1)
        end
      end
    end

    context "with fail-fast on step failure" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            step :process_user
          end

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, index:)
            fail!("failed on #{user}") if user == :failing
            context[:processed] ||= []
            context[:processed] << user
          end
        end
      end
      let(:dependencies) { { input_users: users } }

      context "when all items succeed" do
        let(:users) { %i[alice bob charlie] }

        it "processes all items" do
          expect(result[:processed]).to eq(%i[alice bob charlie])
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end

      context "when an item fails" do
        let(:users) { %i[alice failing charlie] }

        it "stops iteration at the failing item" do
          expect(result[:processed]).to eq(%i[alice])
        end

        it "fails the service" do
          expect(result).to be_failure
        end
      end
    end

    context "with nested DSL (model, only_if inside each)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            model :profile, optional: true

            only_if :has_profile? do
              step :process_profile
            end

            step :process_user
          end

          private

          def fetch_users
            context[:input_users]
          end

          def fetch_profile(user:)
            context[:profiles]&.dig(user)
          end

          def has_profile?(profile:)
            profile.present?
          end

          def process_profile(user:, profile:)
            context[:processed_profiles] ||= []
            context[:processed_profiles] << { user:, profile: }
          end

          def process_user(user:, index:)
            context[:processed_users] ||= []
            context[:processed_users] << user
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob charlie], profiles: } }

      context "when some users have profiles" do
        let(:profiles) { { alice: "Alice Profile", charlie: "Charlie Profile" } }

        it "processes all users" do
          expect(result[:processed_users]).to eq(%i[alice bob charlie])
        end

        it "only processes profiles for users who have them" do
          expect(result[:processed_profiles]).to eq(
            [
              { user: :alice, profile: "Alice Profile" },
              { user: :charlie, profile: "Charlie Profile" },
            ],
          )
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end

      context "when no users have profiles" do
        let(:profiles) { {} }

        it "processes all users" do
          expect(result[:processed_users]).to eq(%i[alice bob charlie])
        end

        it "does not process any profiles" do
          expect(result[:processed_profiles]).to be_nil
        end
      end
    end

    context "with transaction inside each" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            transaction do
              step :step_one
              step :step_two
            end
          end

          private

          def fetch_users
            context[:input_users]
          end

          def step_one(user:)
            context[:step_one_calls] ||= []
            context[:step_one_calls] << user
          end

          def step_two(user:)
            context[:step_two_calls] ||= []
            context[:step_two_calls] << user
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "executes transaction steps for each item" do
        expect(result[:step_one_calls]).to eq(%i[alice bob])
        expect(result[:step_two_calls]).to eq(%i[alice bob])
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end
  end
end
