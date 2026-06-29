# frozen_string_literal: true

RSpec.describe Migrations::Conversion::SetupGuard do
  let(:processor) { instance_double(Migrations::Conversion::Step::Processor) }
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
      connection = instance_double(Migrations::Database::Connection)
      allow(connection).to receive(:insert)
      allow(connection).to receive(:close)
      intermediate_db.setup(connection)

      allow(processor).to receive(:setup) do
        intermediate_db.insert("INSERT INTO foo (id) VALUES (?)", 1)
      end

      expect { described_class.run(processor) }.to raise_error(described_class::SetupError)

      # the guard blocked the write from `setup`; only the write made after it
      # restored the connection gets through
      intermediate_db.insert("INSERT INTO foo (id) VALUES (?)", 2)
      expect(connection).to have_received(:insert).with("INSERT INTO foo (id) VALUES (?)", [2])
      expect(connection).not_to have_received(:insert).with("INSERT INTO foo (id) VALUES (?)", [1])
    end
  end
end
