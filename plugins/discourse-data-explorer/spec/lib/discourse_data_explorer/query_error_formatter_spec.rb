# frozen_string_literal: true

describe DiscourseDataExplorer::QueryErrorFormatter do
  describe ".message" do
    it "includes the error class for query errors" do
      error = DiscourseDataExplorer::ValidationError.new("Invalid parameter")

      expect(described_class.message(error)).to eq(
        "DiscourseDataExplorer::ValidationError: Invalid parameter",
      )
    end

    it "uses the database error class for wrapped statement errors" do
      database_error = PG::UndefinedTable.new("relation does not exist")
      statement_error = nil

      begin
        raise database_error
      rescue PG::UndefinedTable
        begin
          raise ActiveRecord::StatementInvalid.new("PG::UndefinedTable: relation does not exist")
        rescue ActiveRecord::StatementInvalid => error
          statement_error = error
        end
      end

      expect(described_class.message(statement_error)).to eq("relation does not exist")
    end
  end
end
