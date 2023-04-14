# frozen_string_literal: true

RSpec.describe MiniSqlMultisiteConnection do
  describe "after_commit" do
    it "works for 'fake' (joinable) transactions" do
      outputString = "1"

      ActiveRecord::Base.transaction do
        outputString += "2"
        DB.exec("SELECT 1")
        ActiveRecord::Base.transaction do
          DB.exec("SELECT 2")
          outputString += "3"
          DB.after_commit { outputString += "6" }
          outputString += "4"
        end
        DB.after_commit { outputString += "7" }
        outputString += "5"
      end

      expect(outputString).to eq("1234567")
    end

    it "works for real (non-joinable) transactions" do
      outputString = "1"

      ActiveRecord::Base.transaction(requires_new: true, joinable: false) do
        outputString += "2"
        DB.exec("SELECT 1")
        ActiveRecord::Base.transaction(requires_new: true) do
          DB.exec("SELECT 2")
          outputString += "3"
          DB.after_commit { outputString += "6" }
          outputString += "4"
        end
        DB.after_commit { outputString += "7" }
        outputString += "5"
      end

      expect(outputString).to eq("1234567")
    end

    it "does not run if the transaction is rolled back" do
      outputString = "1"

      ActiveRecord::Base.transaction do
        outputString += "2"

        DB.after_commit { outputString += "4" }

        outputString += "3"

        raise ActiveRecord::Rollback
      end

      expect(outputString).to eq("123")
    end

    it "runs immediately if there is no transaction" do
      outputString = "1"

      DB.after_commit { outputString += "2" }

      outputString += "3"

      expect(outputString).to eq("123")
    end

    it "supports prepared statements" do
      DB.prepared.query("SELECT ?", 1)
      DB.prepared.query("SELECT ?", 2)
    end
  end
end
