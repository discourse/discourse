require 'rails_helper'

describe TransactionHelper do

  it "runs callbacks after outermost transaction is committed" do
    outputString = "1"

    # Main transaction
    ActiveRecord::Base.transaction do  
      outputString += "2"

        # Nested transaction
        ActiveRecord::Base.transaction do
          outputString += "3"

            TransactionHelper.after_commit do
              outputString += "6"
            end
            outputString += "4"
        end

        TransactionHelper.after_commit do
          outputString += "7"
        end

        outputString += "5"
    end

    expect(outputString).to eq("1234567")
  end

end
