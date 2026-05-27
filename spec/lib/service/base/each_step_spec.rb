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
      let(:dependencies) { { input_users: %i[alice bob charlie] } }

      it { is_expected.to run_successfully }

      it "provides each item under the singularized name and its index" do
        expect(result[:processed]).to contain_exactly(
          { user: :alice, index: 0 },
          { user: :bob, index: 1 },
          { user: :charlie, index: 2 },
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
    end
  end
end
