# frozen_string_literal: true

require 'rails_helper'

describe TimezoneValidator do
  describe "#valid?" do
    context "when timezone is ok" do
      it "returns true" do
        expect(described_class.valid?("Australia/Brisbane")).to eq(true)
      end
    end

    context "when timezone is not ok" do
      it "returns false" do
        expect(described_class.valid?("Mars")).to eq(false)
      end
    end
  end

  describe "#validate_each" do
    let(:record) { Fabricate(:active_user).user_option }

    context "when timezone is ok" do
      it "adds no errors to the record" do
        record.timezone = "Australia/Melbourne"
        record.save
        expect(record.errors.full_messages.empty?).to eq(true)
      end
    end

    context "when timezone is blank" do
      it "adds no errors to the record" do
        record.timezone = nil
        record.save
        expect(record.errors.full_messages.empty?).to eq(true)
      end
    end

    context "when timezone is not ok" do
      it "adds errors to the record" do
        record.timezone = "Mars"
        record.save
        expect(record.errors.full_messages).to include(
          "Timezone 'Mars' is not a valid timezone"
        )
      end
    end
  end
end
