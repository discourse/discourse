require 'rails_helper'
require_dependency 'migration/table_dropper'

describe Migration::TableDropper do

  def table_exists?(table_name)
    DB.exec(<<~SQL) > 0
      SELECT 1
      FROM INFORMATION_SCHEMA.TABLES
      WHERE table_schema = 'public' AND
            table_name = '#{table_name}'
    SQL
  end

  let(:table_name) { 'table_with_old_name' }

  before do
    DB.exec "CREATE TABLE #{table_name} (topic_id INTEGER)"

    DB.exec <<~SQL
      INSERT INTO #{table_name} (topic_id) VALUES (1)
    SQL
  end

  describe ".execute_drop" do
    it "should drop the table" do
      Migration::TableDropper.execute_drop(table_name)

      expect(table_exists?(table_name)).to eq(false)
    end
  end

  describe ".readonly_only_table" do
    before do
      Migration::TableDropper.read_only_table(table_name)
    end

    after do
      ActiveRecord::Base.connection.reset!

      DB.exec(<<~SQL)
        DROP TABLE IF EXISTS #{table_name};
        DROP FUNCTION IF EXISTS #{Migration::BaseDropper.readonly_function_name(table_name)} CASCADE;
      SQL
    end

    it 'should be droppable' do
      Migration::TableDropper.execute_drop(table_name)

      expect(has_trigger?(Migration::BaseDropper.readonly_trigger_name(
        table_name
      ))).to eq(false)

      expect(table_exists?(table_name)).to eq(false)
    end

    it 'should prevent insertions to the table' do
      begin
        DB.exec <<~SQL
          INSERT INTO #{table_name} (topic_id) VALUES (2)
        SQL
      rescue PG::RaiseException => e
        [
          "Discourse: #{table_name} is read only",
          'discourse_functions.raise_table_with_old_name_readonly()'
        ].each do |message|
          expect(e.message).to include(message)
        end
      end
    end
  end
end
