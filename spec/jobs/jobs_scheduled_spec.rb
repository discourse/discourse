# frozen_string_literal: true

RSpec.describe Jobs::Scheduled do
  describe "#perform" do
    context "when `Discourse.readonly_mode?` is enabled" do
      before { Discourse.enable_readonly_mode }
      after { Discourse.disable_readonly_mode }

      it "does not perform scheduled jobs in readonly mode" do
        Sidekiq::Testing.inline! do
          klass =
            Class.new(described_class) do
              every 1.minute

              @called = 0

              def self.count
                @called
              end

              def self.increment
                @called += 1
              end

              def execute(args)
                self.class.increment
              end
            end

          klass.new.perform(nil)
          expect(klass.count).to eq(0)
        end
      end

      it "still enqueues scheduled jobs that has `perform_when_readonly` option set to true in readonly mode" do
        Sidekiq::Testing.inline! do
          klass =
            Class.new(described_class) do
              every 1.minute
              perform_when_readonly

              @called = 0

              def self.count
                @called
              end

              def self.increment
                @called += 1
              end

              def execute(args)
                self.class.increment
              end
            end

          klass.new.perform(nil)
          expect(klass.count).to eq(1)
        end
      end
    end
  end
end
