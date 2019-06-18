# frozen_string_literal: true

require 'rails_helper'

describe MiniSqlMultisiteConnection do

  describe "after_commit" do
    it "runs callbacks after outermost transaction is committed" do
      outputString = "1"

      # Main transaction
      ActiveRecord::Base.transaction do
        outputString += "2"

          # Nested transaction
          ActiveRecord::Base.transaction do
            outputString += "3"

              DB.after_commit do
                outputString += "6"
              end
              outputString += "4"
          end

          DB.after_commit do
            outputString += "7"
          end

          outputString += "5"
      end

      expect(outputString).to eq("1234567")
    end

    it "does not run if the transaction is rolled back" do
      outputString = "1"

      ActiveRecord::Base.transaction do
        outputString += "2"

        DB.after_commit do
          outputString += "4"
        end

        outputString += "3"

        raise ActiveRecord::Rollback
      end

      expect(outputString).to eq("123")
    end
  end

end
