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

          each :users, persist: { processed: -> { [] } } do
            step :process_user
          end

          step :finalize

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, index:, processed:)
            processed << { user:, index: }
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

          each :users, as: :member, persist: { processed: -> { [] } } do
            step :process_member
          end

          private

          def fetch_users
            context[:input_users]
          end

          def process_member(member:, index:, processed:)
            processed << { member:, index: }
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

          each :users, persist: { processed: -> { [] } } do
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

          def process_user(user:, processed:)
            processed << user
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

          each :users, persist: { processed: -> { [] } } do
            step :process_user
          end

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, processed:)
            fail!("failed on #{user}") if user == :failing
            processed << user
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

          each :users, persist: { processed_profiles: -> { [] }, processed_users: -> { [] } } do
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

          def process_profile(user:, profile:, processed_profiles:)
            processed_profiles << { user:, profile: }
          end

          def process_user(user:, processed_users:)
            processed_users << user
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
          expect(result[:processed_profiles]).to eq([])
        end
      end
    end

    context "with transaction inside each" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: { step_one_calls: -> { [] }, step_two_calls: -> { [] } } do
            transaction do
              step :step_one
              step :step_two
            end
          end

          private

          def fetch_users
            context[:input_users]
          end

          def step_one(user:, step_one_calls:)
            step_one_calls << user
          end

          def step_two(user:, step_two_calls:)
            step_two_calls << user
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

    context "with variable isolation" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            model :profile
            step :process_user
          end

          step :check_isolation

          private

          def fetch_users
            context[:input_users]
          end

          def fetch_profile(user:)
            "#{user}_profile"
          end

          def process_user(user:, profile:)
            context[:last_processed] = user
          end

          def check_isolation
            context[:profile_after_loop] = context[:profile]
            context[:user_after_loop] = context[:user]
            context[:index_after_loop] = context[:index]
            context[:last_processed_after_loop] = context[:last_processed]
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob charlie] } }

      it "discards variables set inside the loop" do
        expect(result[:profile_after_loop]).to be_nil
        expect(result[:user_after_loop]).to be_nil
        expect(result[:index_after_loop]).to be_nil
        expect(result[:last_processed_after_loop]).to be_nil
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with variable isolation restoring existing values" do
      let(:service) do
        Class.new do
          include Service::Base

          step :setup

          each :users do
            step :modify_existing
          end

          step :check_after

          private

          def setup
            context[:users] = %i[alice bob]
            context[:existing_value] = "original"
            context[:existing_hash] = { key: "original_hash" }
          end

          def modify_existing(user:)
            context[:existing_value] = "modified_by_#{user}"
            context[:existing_hash][:key] = "modified_hash_by_#{user}"
          end

          def check_after
            context[:value_after] = context[:existing_value]
            context[:hash_after] = context[:existing_hash]
          end
        end
      end

      it "restores existing scalar values after the loop" do
        expect(result[:value_after]).to eq("original")
      end

      it "restores existing hash values after the loop" do
        expect(result[:hash_after]).to eq({ key: "original_hash" })
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with persist option (lambda initializer)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: { results: -> { { created: [], failed: [] } } } do
            step :process_user
          end

          step :check_results

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, results:)
            if user == :invalid
              results[:failed] << user
            else
              results[:created] << user
            end
          end

          def check_results(results:)
            context[:final_results] = results
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice invalid bob] } }

      it "initializes the persisted key with the lambda result" do
        expect(result[:results]).to eq({ created: %i[alice bob], failed: [:invalid] })
      end

      it "makes persisted key available after the loop" do
        expect(result[:final_results]).to eq({ created: %i[alice bob], failed: [:invalid] })
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with persist option (method symbol initializer)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: { results: :initial_results } do
            step :process_user
          end

          step :check_results

          private

          def fetch_users
            context[:input_users]
          end

          def initial_results
            { processed: [], count: 0 }
          end

          def process_user(user:, results:)
            results[:processed] << user
            results[:count] += 1
          end

          def check_results(results:)
            context[:final_results] = results
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "initializes the persisted key by calling the method" do
        expect(result[:results]).to eq({ processed: %i[alice bob], count: 2 })
      end

      it "makes persisted key available after the loop" do
        expect(result[:final_results]).to eq({ processed: %i[alice bob], count: 2 })
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with persist option (key only, no initializer)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: [:results] do
            step :process_user
          end

          step :check_results

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:)
            context[:results] ||= []
            context[:results] << user
          end

          def check_results(results:)
            context[:final_results] = results
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "persists the key without initialization" do
        expect(result[:results]).to eq(%i[alice bob])
      end

      it "makes persisted key available after the loop" do
        expect(result[:final_results]).to eq(%i[alice bob])
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with persist option (multiple keys)" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: { created: -> { [] }, audit_log: -> { [] } } do
            step :process_user
          end

          step :check_results

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, index:, created:, audit_log:)
            created << user
            audit_log << "Processed #{user} at index #{index}"
          end

          def check_results(created:, audit_log:)
            context[:final_created] = created
            context[:final_audit_log] = audit_log
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "persists all specified keys" do
        expect(result[:created]).to eq(%i[alice bob])
        expect(result[:audit_log]).to eq(["Processed alice at index 0", "Processed bob at index 1"])
      end

      it "makes all persisted keys available after the loop" do
        expect(result[:final_created]).to eq(%i[alice bob])
        expect(result[:final_audit_log]).to eq(
          ["Processed alice at index 0", "Processed bob at index 1"],
        )
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end

    context "with persist and empty collection" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users, optional: true

          each :users, persist: { results: -> { [] } } do
            step :process_user
          end

          step :check_results

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, results:)
            results << user
          end

          def check_results
            context[:has_results] = !context[:results].nil?
            context[:final_results] = context[:results]
          end
        end
      end
      let(:dependencies) { { input_users: [] } }

      it "still initializes persisted keys" do
        expect(result[:has_results]).to be true
        expect(result[:final_results]).to eq([])
      end

      it "succeeds" do
        expect(result).to be_success
      end
    end
  end
end
