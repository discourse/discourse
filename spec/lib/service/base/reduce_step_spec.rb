# frozen_string_literal: true

RSpec.describe Service::Base::EachStep do
  describe "Reduce syntactic sugar" do
    describe "#call" do
      subject(:result) { service.call(dependencies) }

      let(:dependencies) { {} }

      context "with basic accumulation" do
        let(:service) do
          Class.new do
            include Service::Base

            model :tag_names

            reduce :tag_names, into: :results, initial: -> { { created: [], failed: [] } } do
              step :process_tag
            end

            private

            def fetch_tag_names
              context[:input_tag_names]
            end

            def process_tag(tag_name:, results:)
              if tag_name.start_with?("invalid")
                results[:failed] << tag_name
              else
                results[:created] << tag_name
              end
            end
          end
        end
        let(:dependencies) { { input_tag_names: %w[ruby rails invalid_tag elixir] } }

        it "accumulates results across iterations" do
          expect(result[:results]).to eq(created: %w[ruby rails elixir], failed: %w[invalid_tag])
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end

      context "with method symbol as initial value" do
        let(:service) do
          Class.new do
            include Service::Base

            model :items

            reduce :items, into: :results, initial: :empty_results do
              step :process_item
            end

            private

            def fetch_items
              context[:input_items]
            end

            def empty_results
              { processed: [], count: 0 }
            end

            def process_item(item:, results:)
              results[:processed] << item
              results[:count] += 1
            end
          end
        end
        let(:dependencies) { { input_items: %i[a b c] } }

        it "initializes the accumulator by calling the method" do
          expect(result[:results]).to eq(processed: %i[a b c], count: 3)
        end
      end

      context "with default initial value" do
        let(:service) do
          Class.new do
            include Service::Base

            model :items

            reduce :items, into: :results do
              step :process_item
            end

            private

            def fetch_items
              context[:input_items]
            end

            def process_item(item:, results:)
              results[item] = true
            end
          end
        end
        let(:dependencies) { { input_items: %i[a b] } }

        it "defaults to an empty hash" do
          expect(result[:results]).to eq(a: true, b: true)
        end
      end

      context "with custom item name" do
        let(:service) do
          Class.new do
            include Service::Base

            model :users

            reduce :users, into: :results, initial: -> { [] }, as: :member do
              step :process_member
            end

            private

            def fetch_users
              context[:input_users]
            end

            def process_member(member:, results:)
              results << member
            end
          end
        end
        let(:dependencies) { { input_users: %i[alice bob] } }

        it "uses the custom item name" do
          expect(result[:results]).to eq(%i[alice bob])
        end
      end

      context "with empty collection" do
        let(:service) do
          Class.new do
            include Service::Base

            model :items, optional: true

            reduce :items, into: :results, initial: -> { [] } do
              step :process_item
            end

            step :check_results

            private

            def fetch_items
              context[:input_items]
            end

            def process_item(item:, results:)
              results << item
            end

            def check_results
              context[:final_results] = context[:results]
            end
          end
        end
        let(:dependencies) { { input_items: [] } }

        it "still initializes the accumulator" do
          expect(result[:results]).to eq([])
        end

        it "makes the accumulator available to subsequent steps" do
          expect(result[:final_results]).to eq([])
        end
      end

      context "with fail! as escape hatch" do
        let(:service) do
          Class.new do
            include Service::Base

            model :items

            reduce :items, into: :results, initial: -> { [] } do
              step :process_item
            end

            private

            def fetch_items
              context[:input_items]
            end

            def process_item(item:, results:)
              fail!("critical error on #{item}") if item == :critical
              results << item
            end
          end
        end
        let(:dependencies) { { input_items: %i[a b critical c] } }

        it "stops iteration on fail!" do
          expect(result[:results]).to eq(%i[a b])
        end

        it "fails the service" do
          expect(result).to be_failure
        end
      end

      context "with nested steps inside reduce" do
        let(:service) do
          Class.new do
            include Service::Base

            model :users

            reduce :users, into: :audit_log, initial: -> { [] } do
              policy :can_modify

              transaction do
                step :update_user
                step :log_action
              end
            end

            private

            def fetch_users
              context[:input_users]
            end

            def can_modify(user:)
              user != :admin
            end

            def update_user(user:)
              # no-op
            end

            def log_action(user:, audit_log:)
              audit_log << "updated #{user}"
            end
          end
        end
        let(:dependencies) { { input_users: %i[alice bob] } }

        it "supports the full DSL inside reduce" do
          expect(result[:audit_log]).to eq(["updated alice", "updated bob"])
        end

        it "succeeds" do
          expect(result).to be_success
        end
      end
    end
  end
end
