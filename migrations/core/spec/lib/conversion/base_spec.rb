# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Base do
  describe "#run" do
    let(:offline_connection) { Migrations::Database::OfflineConnection.new }
    let(:converter) do
      TemporaryConverterModule::Converter.new({ intermediate_db: { path: "intermediate.db" } })
    end

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set(
            "Topics",
            Class.new(Migrations::Conversion::ProgressStep) do
              title "Converting topics"
              # forces `execute_in_parallel?` to consult the pool's size; with
              # `max_progress` below the parallel threshold the step still runs
              # serially, so a missing pool fails fast without forking workers
              run_in_parallel true

              source do
                def max_progress
                  5
                end

                def items
                  Array.new(5) { |index| { id: index } }
                end
              end

              processor do
                def process(item)
                  Migrations::Database::IntermediateDB.insert(
                    "INSERT INTO topics (original_id) VALUES (?)",
                    item[:id],
                  )
                end
              end
            end,
          )
          const_set(
            "Users",
            Class.new(Migrations::Conversion::Step) do
              title "Converting users"

              def execute
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO users (original_id) VALUES (?)",
                  1,
                )
              end
            end,
          )
        end,
      )

      Migrations::Database::IntermediateDB.setup(offline_connection)
      # `run` closes the IntermediateDB in its `ensure`, which would discard
      # the recorded insert statements before they can be verified
      allow(offline_connection).to receive(:close)
      allow(converter).to receive(:create_database)
    end

    after do
      Migrations::Database::IntermediateDB.setup(nil)
      Object.send(:remove_const, "TemporaryConverterModule")
    end

    it "creates one pool and one reporter per run and wires them through both executor kinds" do
      reporter = nil
      allow(Migrations::Conversion::WorkerPool).to receive(:new).and_call_original
      allow(Migrations::Conversion::ConsoleReporter).to receive(
        :new,
      ).and_wrap_original do |original|
        reporter = original.call
        allow(reporter).to receive(:close).and_call_original
        reporter
      end

      expect { converter.run }.to output(/Converting topics.*Converting users/m).to_stdout

      expect(Migrations::Conversion::WorkerPool).to have_received(:new).once
      expect(Migrations::Conversion::ConsoleReporter).to have_received(:new).once
      expect(reporter).to have_received(:close).once
      expect(offline_connection.parametrized_insert_statements).to eq(
        [
          *Array.new(5) { |index| ["INSERT INTO topics (original_id) VALUES (?)", [index]] },
          ["INSERT INTO users (original_id) VALUES (?)", [1]],
        ],
      )
    end
  end

  describe "#steps" do
    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Topics", Class.new(Migrations::Conversion::ProgressStep))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
        end,
      )
    end

    after { Object.send(:remove_const, "TemporaryConverterModule") }

    it "discovers both `Step` and `ProgressStep` subclasses" do
      converter = TemporaryConverterModule::Converter.new(nil)

      expect(converter.steps).to eq(
        [TemporaryConverterModule::Topics, TemporaryConverterModule::Users],
      )
    end
  end
end
