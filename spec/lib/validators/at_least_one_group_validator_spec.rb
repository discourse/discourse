# frozen_string_literal: true

RSpec.describe AtLeastOneGroupValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    context "when using a blank value" do
      it { expect(validator.valid_value?(nil)).to eq(false) }
    end

    context "when one of the groups doesn't exist" do
      it { expect(validator.valid_value?("10|1337")).to eq(false) }
    end

    context "when all the groups exist" do
      it { expect(validator.valid_value?("10|11")).to eq(true) }
    end
  end

  describe "#error_message" do
    context "when using a blank value" do
      before { validator.valid_value?(nil) }

      it do
        expect(validator.error_message).to eq(
          "You must specify at least one group for this setting.",
        )
      end
    end

    context "when one of the groups doesn't exist" do
      before { validator.valid_value?("10|1337") }

      it { expect(validator.error_message).to eq("There's no group with that name.") }
    end
  end
end
