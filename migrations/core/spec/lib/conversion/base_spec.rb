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
      allow(Migrations::Conversion::WorkerPool).to receive(:new).and_call_original
      allow(Migrations::Conversion::ConsoleReporter).to receive(:new).and_call_original

      expect { converter.run }.to output(/Converting topics.*Converting users/m).to_stdout

      expect(Migrations::Conversion::WorkerPool).to have_received(:new).once
      expect(Migrations::Conversion::ConsoleReporter).to have_received(:new).once
      expect(offline_connection.parametrized_insert_statements).to eq(
        [
          *Array.new(5) { |index| ["INSERT INTO topics (original_id) VALUES (?)", [index]] },
          ["INSERT INTO users (original_id) VALUES (?)", [1]],
        ],
      )
    end
  end

  describe "#steps" do
    subject(:converter) { TemporaryConverterModule::Converter.new(nil) }

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Categories", Class.new(Migrations::Conversion::Step))
          const_set("Topics", Class.new(Migrations::Conversion::ProgressStep))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
        end,
      )
    end

    after { Object.send(:remove_const, "TemporaryConverterModule") }

    it "discovers both `Step` and `ProgressStep` subclasses" do
      expect(converter.steps).to contain_exactly(
        TemporaryConverterModule::Categories,
        TemporaryConverterModule::Topics,
        TemporaryConverterModule::Users,
      )
    end

    it "returns steps in alphabetical order when no dependencies are declared" do
      # Regression for the switch from `sort_by(&:to_s)` to `TopologicalSorter`:
      # without dependencies and priorities, the order must stay exactly the
      # alphabetical order the previous implementation produced.
      expect(converter.steps).to eq(
        [
          TemporaryConverterModule::Categories,
          TemporaryConverterModule::Topics,
          TemporaryConverterModule::Users,
        ],
      )
    end

    it "orders steps after their dependencies regardless of alphabetical order" do
      TemporaryConverterModule::Categories.depends_on(:users)

      expect(converter.steps).to eq(
        [
          TemporaryConverterModule::Topics,
          TemporaryConverterModule::Users,
          TemporaryConverterModule::Categories,
        ],
      )
    end

    it "raises an error for circular dependencies" do
      TemporaryConverterModule::Categories.depends_on(:users)
      TemporaryConverterModule::Users.depends_on(:categories)

      expect { converter.steps }.to raise_error(
        Migrations::TopologicalSorterError,
        "Circular dependency detected",
      )
    end

    it "keeps pulled-in dependencies ordered before the steps that depend on them" do
      TemporaryConverterModule::Categories.depends_on(:users)

      # `--only categories` pulls in the `users` dependency; it has to run
      # before `categories` because the filtered list is executed as-is.
      filtered = converter.send(:filter_steps, converter.steps, ["categories"], [])

      expect(filtered).to eq(
        [TemporaryConverterModule::Users, TemporaryConverterModule::Categories],
      )
    end

    it "supports running a single step via `--only` even when its dependency is excluded" do
      TemporaryConverterModule::Categories.depends_on(:users)

      # `run` sorts the full step set first and filters afterwards, so
      # re-running a single step keeps working even when its dependency
      # isn't part of the filtered set.
      filtered = converter.send(:filter_steps, converter.steps, ["categories"], ["users"])

      expect(filtered).to eq([TemporaryConverterModule::Categories])
    end
  end
end
