# frozen_string_literal: true

RSpec.describe Migrations::Conversion::ProgressStepExecutor do
  subject(:executor) { described_class.new(step, pool:, reporter:) }

  let(:pool_size) { 2 }
  let(:pool) { Migrations::Conversion::WorkerPool.new(size: pool_size) }
  let(:reporter) { Migrations::Reporting::Plain.new(output: StringIO.new) }
  let(:item_count) { 30 }
  let(:offline_connection) { Migrations::Database::OfflineConnection.new }
  let(:step) { step_class.new(settings: { item_count: }) }

  before { Migrations::Database::IntermediateDB.setup(offline_connection) }
  after { Migrations::Database::IntermediateDB.setup(nil) }

  def define_fixture_step(run_parallel)
    Class.new(Migrations::Conversion::ProgressStep) do
      title "Fixture step"
      run_in_parallel run_parallel

      source do
        def max_progress
          settings[:item_count]
        end

        def items
          Array.new(settings[:item_count]) { |index| { id: index } }
        end
      end

      processor do
        def setup
          @prefix = "item"
        end

        def process(item)
          Migrations::Database::IntermediateDB.insert(
            "INSERT INTO items (name) VALUES (?)",
            "#{@prefix}-#{item[:id]}",
          )
        end
      end
    end
  end

  def expected_insert_statements
    Array.new(item_count) { |index| ["INSERT INTO items (name) VALUES (?)", ["item-#{index}"]] }
  end

  def execute_quietly
    original_stdout = $stdout
    $stdout = StringIO.new
    executor.execute
  ensure
    $stdout = original_stdout
  end

  describe "#execute" do
    context "when the step runs serially" do
      let(:step_class) { define_fixture_step(false) }

      it "runs the processor's `setup` and processes all items in order" do
        execute_quietly

        expect(offline_connection.parametrized_insert_statements).to eq(expected_insert_statements)
      end
    end

    context "when the step runs in parallel" do
      let(:step_class) { define_fixture_step(true) }

      it "forks workers and produces the same inserts as a serial run" do
        allow(Migrations::ForkManager).to receive(:fork).and_call_original

        execute_quietly

        expect(Migrations::ForkManager).to have_received(:fork).at_least(:once)
        expect(offline_connection.parametrized_insert_statements).to match_array(
          expected_insert_statements,
        )
      end
    end

    context "when calculating the max progress is slow" do
      let(:step_class) { define_fixture_step(false) }
      let(:events) { [] }
      let(:reporter) do
        handle = instance_double(Migrations::Reporting::Reporter::StepHandle)
        allow(handle).to receive(:notice) { events << :notice }
        allow(handle).to receive(:with_progress) { events << :with_progress }
        allow(handle).to receive(:finish) { events << :finish }

        instance_double(Migrations::Reporting::Plain).tap do |reporter|
          allow(reporter).to receive(:start_step) do
            events << :start_step
            handle
          end
        end
      end

      it "announces the step before the runtime notice and reports the step end last" do
        allow(Time).to receive(:now).and_return(Time.at(0), Time.at(10))

        executor.execute

        expect(events).to eq(%i[start_step notice with_progress finish])
      end
    end

    context "when the parallel threshold scales with the pool size" do
      let(:step_class) { define_fixture_step(true) }

      context "with no more items than `pool.size * 10`" do
        let(:item_count) { pool_size * 10 }

        it "runs serially despite `run_in_parallel`" do
          allow(Migrations::ForkManager).to receive(:fork).and_call_original

          execute_quietly

          expect(Migrations::ForkManager).not_to have_received(:fork)
          expect(offline_connection.parametrized_insert_statements).to eq(
            expected_insert_statements,
          )
        end
      end

      context "with one item more than `pool.size * 10`" do
        let(:item_count) { pool_size * 10 + 1 }

        it "runs in parallel" do
          allow(Migrations::ForkManager).to receive(:fork).and_call_original

          execute_quietly

          expect(Migrations::ForkManager).to have_received(:fork).exactly(pool_size).times
          expect(offline_connection.parametrized_insert_statements).to match_array(
            expected_insert_statements,
          )
        end
      end
    end
  end
end
