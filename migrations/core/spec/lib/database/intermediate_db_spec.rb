# frozen_string_literal: true

RSpec.describe Migrations::Database::IntermediateDB do
  before { reset_memoization(described_class, :@db) }
  after { reset_memoization(described_class, :@db) }

  def create_connection_double
    connection = instance_double(Migrations::Database::Connection)
    allow(connection).to receive(:insert)
    allow(connection).to receive(:close)
    connection
  end

  describe ".setup" do
    it "works with `Migrations::Database::Connection`" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        connection = Migrations::Database::Connection.new(path: db_path)

        connection.db.execute("CREATE TABLE foo (id INTEGER)")

        described_class.setup(connection)
        described_class.insert("INSERT INTO foo (id) VALUES (?)", 1)
        described_class.insert("INSERT INTO foo (id) VALUES (?)", 2)

        expect(connection.db.query_splat("SELECT id FROM foo")).to contain_exactly(1, 2)

        connection.close
      end
    end

    it "switches the connection" do
      old_connection = create_connection_double
      new_connection = create_connection_double

      sql = "INSERT INTO foo (id) VALUES (?)"

      described_class.setup(old_connection)
      described_class.insert(sql, 1)
      expect(old_connection).to have_received(:insert).with(sql, [1])
      expect(new_connection).to_not have_received(:insert)

      described_class.setup(new_connection)
      described_class.insert(sql, 2)
      expect(old_connection).to_not have_received(:insert).with(sql, [2])
      expect(new_connection).to have_received(:insert).with(sql, [2])
    end

    it "closes a previous connection" do
      old_connection = create_connection_double
      new_connection = create_connection_double

      described_class.setup(old_connection)
      described_class.setup(new_connection)
      expect(old_connection).to have_received(:close)
      expect(new_connection).to_not have_received(:close)
    end
  end

  describe ".conflict_strategy_for" do
    it "returns `:ignore` for a table whose model declares it" do
      expect(described_class.conflict_strategy_for("uploads")).to eq(:ignore)
    end

    it "returns `:raise` for a table whose model does not declare a strategy" do
      expect(described_class.conflict_strategy_for("topic_tags")).to eq(:raise)
    end

    it "returns `:raise` for a table without a model" do
      expect(described_class.conflict_strategy_for("schema_migrations")).to eq(:raise)
    end

    it "accepts a symbol table name" do
      expect(described_class.conflict_strategy_for(:uploads)).to eq(:ignore)
    end

    it "ignores top-level constants that are not defined on the module itself" do
      # `strings` camelizes to `String`, a top-level constant. The lookup must
      # stay scoped to this module (no inherited constants), so it counts as
      # having no model and raises on a duplicate.
      expect(described_class.conflict_strategy_for("strings")).to eq(:raise)
    end

    it "reads the strategy from the model, so a new `OR IGNORE` model flips it" do
      model =
        Module.new do
          def self.conflict_strategy
            :ignore
          end
        end
      stub_const("#{described_class}::Widget", model)

      expect(described_class.conflict_strategy_for("widgets")).to eq(:ignore)
    end
  end

  describe ".with_connection" do
    let(:previous_connection) { create_connection_double }
    let(:temporary_connection) { create_connection_double }
    let(:sql) { "INSERT INTO foo (id) VALUES (?)" }

    before { described_class.setup(previous_connection) }

    it "swaps the connection for the duration of the block and restores it afterwards" do
      described_class.with_connection(temporary_connection) { described_class.insert(sql, 1) }
      described_class.insert(sql, 2)

      expect(temporary_connection).to have_received(:insert).with(sql, [1])
      expect(previous_connection).to have_received(:insert).with(sql, [2])
      expect(previous_connection).to_not have_received(:insert).with(sql, [1])
    end

    it "restores the previous connection when the block raises" do
      expect do
        described_class.with_connection(temporary_connection) { raise "boom" }
      end.to raise_error("boom")

      described_class.insert(sql, 1)
      expect(previous_connection).to have_received(:insert).with(sql, [1])
    end

    it "closes neither connection" do
      described_class.with_connection(temporary_connection) { nil }

      expect(previous_connection).to_not have_received(:close)
      expect(temporary_connection).to_not have_received(:close)
    end

    it "returns the value of the block" do
      expect(described_class.with_connection(temporary_connection) { 42 }).to eq(42)
    end
  end

  context "with fake connection" do
    let(:connection) { create_connection_double }
    let!(:sql) { "INSERT INTO foo (id, name) VALUES (?, ?)" }

    before { described_class.setup(connection) }

    describe ".insert" do
      it "calls `#insert` on the connection" do
        described_class.insert(sql, 1, "Alice")
        expect(connection).to have_received(:insert).with(sql, [1, "Alice"])
      end
    end

    describe ".close" do
      it "closes the underlying connection" do
        described_class.close
        expect(connection).to have_received(:close).with(no_args)
      end
    end
  end
end
