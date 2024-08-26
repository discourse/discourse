# frozen_string_literal: true

RSpec.describe ::Migrations::Database::OfflineConnection do
  subject(:connection) { described_class.new }

  let!(:sql) { "INSERT INTO foo (id, name) VALUES (?, ?)" }

  it_behaves_like "a database connection"

  describe "#close" do
    it "removes the cached statements" do
      connection.insert(sql, [1, "Alice"])
      connection.insert(sql, [2, "Bob"])

      expect(connection.parametrized_insert_statements).to_not be_empty

      connection.close
      expect(connection.parametrized_insert_statements).to be_nil
    end
  end

  describe "#closed?" do
    it "correctly reports if connection is closed" do
      expect(connection.closed?).to be false
      connection.close
      expect(connection.closed?).to be true
    end
  end

  describe "#insert" do
    it "can be called without errors" do
      expect { connection.insert(sql, [1, "Alice"]) }.not_to raise_error
    end
  end

  describe "#parametrized_insert_statements" do
    it "returns an empty array if nothing has been cached" do
      expect(connection.parametrized_insert_statements).to eq([])
    end

    it "returns the cached INSERT statements and parameters in original order" do
      connection.insert(sql, [1, "Alice"])
      connection.insert(sql, [2, "Bob"])
      connection.insert(sql, [3, "Carol"])

      expected_data = [[sql, [1, "Alice"]], [sql, [2, "Bob"]], [sql, [3, "Carol"]]]
      expect(connection.parametrized_insert_statements).to eq(expected_data)

      # multiple calls return the same data
      expect(connection.parametrized_insert_statements).to eq(expected_data)
      expect(connection.parametrized_insert_statements).to eq(expected_data)
    end
  end

  describe "#clear!" do
    it "clears all cached data" do
      connection.insert(sql, [1, "Alice"])
      connection.insert(sql, [2, "Bob"])
      connection.insert(sql, [3, "Carol"])

      expect(connection.parametrized_insert_statements).to_not be_empty

      connection.clear!
      expect(connection.parametrized_insert_statements).to eq([])
    end
  end
end
