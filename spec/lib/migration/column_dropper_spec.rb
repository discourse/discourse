# frozen_string_literal: true

RSpec.describe Migration::ColumnDropper do
  def has_column?(table, column)
    DB.exec(<<~SQL, table: table, column: column) == 1
      SELECT 1
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE
        table_schema = 'public' AND
        table_name = :table AND
        column_name = :column
    SQL
  end

  describe ".execute_drop" do
    let(:columns) { %w[junk junk2] }

    before { columns.each { |column| DB.exec("ALTER TABLE topics ADD COLUMN #{column} int") } }

    after do
      columns.each { |column| DB.exec("ALTER TABLE topics DROP COLUMN IF EXISTS #{column}") }
    end

    it "drops the columns" do
      Migration::ColumnDropper.execute_drop("topics", columns)

      columns.each { |column| expect(has_column?("topics", column)).to eq(false) }
    end
  end

  describe ".mark_readonly" do
    let(:table_name) { "table_with_readonly_column" }

    before do
      DB.exec <<~SQL
      CREATE TABLE #{table_name} (topic_id INTEGER, email TEXT);

      INSERT INTO #{table_name} (topic_id, email)
      VALUES (1, 'something@email.com');
      SQL

      Migration::ColumnDropper.mark_readonly(table_name, "email")
    end

    after do
      ActiveRecord::Base.connection.reset!

      DB.exec <<~SQL
      DROP TABLE IF EXISTS #{table_name};
      DROP FUNCTION IF EXISTS #{Migration::BaseDropper.readonly_function_name(table_name, "email")} CASCADE;
      SQL
    end

    it "should be droppable" do
      Migration::ColumnDropper.execute_drop(table_name, ["email"])

      expect(has_trigger?(Migration::BaseDropper.readonly_trigger_name(table_name, "email"))).to eq(
        false,
      )

      expect(has_column?(table_name, "email")).to eq(false)
    end

    it "should prevent updates to the readonly column" do
      begin
        DB.exec <<~SQL
        UPDATE #{table_name}
        SET email = 'testing@email.com'
        WHERE topic_id = 1;
        SQL
      rescue PG::RaiseException => e
        [
          "Discourse: email in #{table_name} is readonly",
          "discourse_functions.raise_table_with_readonly_column_email_readonly()",
        ].each { |message| expect(e.message).to include(message) }
      end
    end

    it "should allow updates to the other columns" do
      DB.exec <<~SQL
      UPDATE #{table_name}
      SET topic_id = 2
      WHERE topic_id = 1
      SQL

      expect(DB.query("SELECT * FROM #{table_name};").first.values).to include 2,
              "something@email.com"
    end

    it "should prevent insertions to the readonly column" do
      expect do ActiveRecord::Base.connection.raw_connection.exec <<~SQL end.to raise_error(
        INSERT INTO #{table_name} (topic_id, email)
        VALUES (2, 'something@email.com');
        SQL
        PG::RaiseException,
        /Discourse: email in table_with_readonly_column is readonly/,
      )
    end

    it "should allow insertions to the other columns" do
      DB.exec <<~SQL
      INSERT INTO #{table_name} (topic_id)
      VALUES (2);
      SQL

      expect(DB.query_single("SELECT topic_id FROM #{table_name} WHERE topic_id = 2")).to eq([2])
    end
  end
end
