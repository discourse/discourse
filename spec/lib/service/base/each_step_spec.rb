# frozen_string_literal: true

RSpec.describe Service::Base::EachStep do
  describe "#call" do
    subject(:result) { service.call(dependencies) }

    let(:dependencies) { {} }

    context "when iterating over a collection" do
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
      let(:users) { %i[alice bob charlie] }

      it { is_expected.to run_successfully }

      it "provides each item under the singularized name and its index" do
        expect(result[:processed]).to eq(
          [{ user: :alice, index: 0 }, { user: :bob, index: 1 }, { user: :charlie, index: 2 }],
        )
      end

      it "continues to subsequent steps after iteration" do
        expect(result[:finalized]).to be true
      end
    end

    context "when using the as: option" do
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

          def process_member(member:, processed:)
            processed << member
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it "provides items under the custom name" do
        expect(result[:processed]).to contain_exactly(:alice, :bob)
      end
    end

    context "when collection is empty" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users, optional: true

          each :users, persist: { processed: -> { [] } } do
            step :process_user
          end

          private

          def fetch_users
            context[:input_users]
          end

          def process_user(user:, processed:)
            processed << user
          end
        end
      end

      context "with an empty array" do
        let(:dependencies) { { input_users: [] } }

        it { is_expected.to run_successfully }

        it "skips iteration and initializes persisted keys" do
          expect(result[:processed]).to eq([])
        end
      end

      context "with nil" do
        let(:dependencies) { { input_users: nil } }

        it { is_expected.to run_successfully }

        it "skips iteration and initializes persisted keys" do
          expect(result[:processed]).to eq([])
        end
      end
    end

    context "when a policy fails inside the loop" do
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

      context "when all items pass" do
        let(:users) { %i[alice bob charlie] }

        it { is_expected.to run_successfully }

        it "processes all items" do
          expect(result[:processed]).to contain_exactly(:alice, :bob, :charlie)
        end
      end

      context "when one item fails" do
        let(:users) { %i[alice forbidden charlie] }

        it { is_expected.to fail_a_policy(:can_process) }

        it "stops iteration at the failing item" do
          expect(result[:processed]).to eq(%i[alice])
        end

        it "exposes the failing item and index in context" do
          expect(result).to have_attributes(user: :forbidden, index: 1)
        end
      end
    end

    context "when a step calls fail! inside the loop" do
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
      let(:dependencies) { { input_users: %i[alice failing charlie] } }

      it { is_expected.to fail_a_step(:process_user) }

      it "stops iteration at the failing item" do
        expect(result[:processed]).to contain_exactly(:alice)
      end
    end

    context "when a model is not found inside the loop" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users do
            model :profile
            step :process_profile
          end

          private

          def fetch_users
            context[:input_users]
          end

          def fetch_profile(user:)
            { alice: "Alice Profile" }[user]
          end

          def process_profile(profile:)
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it { is_expected.to fail_to_find_a_model(:profile) }
    end

    context "with nested DSL steps" do
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
      let(:profiles) { { alice: "Alice Profile", charlie: "Charlie Profile" } }

      it { is_expected.to run_successfully }

      it "runs all nested step types per item" do
        expect(result).to have_attributes(
          processed_users: a_collection_containing_exactly(:alice, :bob, :charlie),
          processed_profiles:
            a_collection_containing_exactly(
              { user: :alice, profile: "Alice Profile" },
              { user: :charlie, profile: "Charlie Profile" },
            ),
        )
      end
    end

    context "with transaction inside each" do
      let(:service) do
        Class.new do
          include Service::Base

          model :users

          each :users, persist: { calls: -> { [] } } do
            transaction do
              step :step_one
              step :step_two
            end
          end

          private

          def fetch_users
            context[:input_users]
          end

          def step_one(user:, calls:)
            calls << :"#{user}_one"
          end

          def step_two(user:, calls:)
            calls << :"#{user}_two"
          end
        end
      end
      let(:dependencies) { { input_users: %i[alice bob] } }

      it { is_expected.to run_successfully }

      it "wraps each iteration in its own transaction" do
        expect(result[:calls]).to eq(%i[alice_one alice_two bob_one bob_two])
      end
    end

    context "with variable isolation" do
      let(:service) do
        Class.new do
          include Service::Base

          step :setup

          each :users do
            model :profile
            step :track
          end

          step :check_after

          private

          def setup
            context[:users] = %i[alice bob]
            context[:existing_value] = "original"
          end

          def fetch_profile(user:)
            "#{user}_profile"
          end

          def track(user:)
            context[:set_inside_loop] = user
          end

          def check_after
            context[:profile_after] = context[:profile]
            context[:user_after] = context[:user]
            context[:index_after] = context[:index]
            context[:set_inside_after] = context[:set_inside_loop]
            context[:existing_after] = context[:existing_value]
          end
        end
      end

      it "discards non-persisted variables set inside the loop" do
        expect(result).to have_attributes(profile_after: nil, set_inside_after: nil)
      end

      it "keeps the last item and index after the loop" do
        expect(result).to have_attributes(user_after: :bob, index_after: 1)
      end

      it "restores pre-existing values after the loop" do
        expect(result).to have_attributes(existing_after: "original")
      end
    end

    context "with persist option" do
      context "with a lambda initializer" do
        let(:service) do
          Class.new do
            include Service::Base

            model :users

            each :users, persist: { results: -> { { created: [], failed: [] } } } do
              step :process_user
            end

            private

            def fetch_users
              context[:input_users]
            end

            def process_user(user:, results:)
              user == :invalid ? results[:failed] << user : results[:created] << user
            end
          end
        end
        let(:dependencies) { { input_users: %i[alice invalid bob] } }

        it "initializes and accumulates across iterations" do
          expect(result[:results]).to eq(created: %i[alice bob], failed: [:invalid])
        end
      end

      context "with a method symbol initializer" do
        let(:service) do
          Class.new do
            include Service::Base

            model :users

            each :users, persist: { results: :initial_results } do
              step :process_user
            end

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
          end
        end
        let(:dependencies) { { input_users: %i[alice bob] } }

        it "initializes by calling the method" do
          expect(result[:results]).to eq(processed: %i[alice bob], count: 2)
        end
      end

      context "with a key-only array" do
        let(:service) do
          Class.new do
            include Service::Base

            model :users

            each :users, persist: [:results] do
              step :process_user
            end

            private

            def fetch_users
              context[:input_users]
            end

            def process_user(user:)
              context[:results] ||= []
              context[:results] << user
            end
          end
        end
        let(:dependencies) { { input_users: %i[alice bob] } }

        it "persists the key without initialization" do
          expect(result[:results]).to contain_exactly(:alice, :bob)
        end
      end

      context "with multiple keys" do
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

        it "persists all keys and makes them available after the loop" do
          expect(result).to have_attributes(
            final_created: a_collection_containing_exactly(:alice, :bob),
            final_audit_log:
              a_collection_containing_exactly(
                "Processed alice at index 0",
                "Processed bob at index 1",
              ),
          )
        end
      end
    end
  end
end
