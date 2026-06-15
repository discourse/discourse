# frozen_string_literal: true

RSpec.describe Migrations::Conversion::SetupGuard do
  let(:processor) { instance_double(Migrations::Conversion::ProgressStep::Processor) }
  let(:intermediate_db) { Migrations::Database::IntermediateDB }

  before { reset_memoization(intermediate_db, :@db) }
  after { reset_memoization(intermediate_db, :@db) }

  describe ".run" do
    it "runs the processor's `setup`" do
      allow(processor).to receive(:setup)

      described_class.run(processor)

      expect(processor).to have_received(:setup)
    end

    it "raises an error when `setup` writes to the IntermediateDB" do
      allow(processor).to receive(:setup) do
        intermediate_db.insert("INSERT INTO foo (id) VALUES (?)", 1)
      end

      expect { described_class.run(processor) }.to raise_error(
        described_class::SetupError,
        /must not create IntermediateDB records during `setup`/,
      )
    end

    it "restores the previous connection, even when `setup` writes" do
      connection = Migrations::Database::OfflineConnection.new
      intermediate_db.setup(connection)

      allow(processor).to receive(:setup) do
        intermediate_db.insert("INSERT INTO foo (id) VALUES (?)", 1)
      end

      expect { described_class.run(processor) }.to raise_error(described_class::SetupError)

      intermediate_db.insert("INSERT INTO foo (id) VALUES (?)", 2)
      expect(connection.parametrized_insert_statements).to eq(
        [["INSERT INTO foo (id) VALUES (?)", [2]]],
      )
    end
  end
end
