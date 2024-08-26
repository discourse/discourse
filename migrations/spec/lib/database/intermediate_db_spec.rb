# frozen_string_literal: true

RSpec.describe ::Migrations::Database::IntermediateDB do
  before(:each) do
    if described_class.instance_variable_defined?(:@db)
      described_class.remove_instance_variable(:@db)
    end
  end

  def create_connection_double
    connection = instance_double(::Migrations::Database::Connection)
    allow(connection).to receive(:insert)
    allow(connection).to receive(:close)
    connection
  end

  describe ".setup" do
    it "works with `::Migrations::Database::Connection`" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        connection = ::Migrations::Database::Connection.new(path: db_path)

        connection.db.execute("CREATE TABLE foo (id INTEGER)")

        described_class.setup(connection)
        described_class.insert("INSERT INTO foo (id) VALUES (?)", 1)
        described_class.insert("INSERT INTO foo (id) VALUES (?)", 2)

        expect(connection.db.query_splat("SELECT id FROM foo")).to contain_exactly(1, 2)

        connection.close
      end
    end

    it "works with `::Migrations::Database::OfflineConnection`" do
      connection = ::Migrations::Database::OfflineConnection.new

      described_class.setup(connection)
      described_class.insert("INSERT INTO foo (id, name) VALUES (?, ?)", 1, "Alice")
      described_class.insert("INSERT INTO foo (id, name) VALUES (?, ?)", 2, "Bob")

      expect(connection.parametrized_insert_statements).to eq(
        [
          ["INSERT INTO foo (id, name) VALUES (?, ?)", [1, "Alice"]],
          ["INSERT INTO foo (id, name) VALUES (?, ?)", [2, "Bob"]],
        ],
      )

      connection.close
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
