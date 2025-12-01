# frozen_string_literal: true

RSpec.describe TopicSettingValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    fab!(:topic)

    it "has a valid error message" do
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_topic"))
    end

    it "returns true for blank values" do
      expect(validator.valid_value?("")).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns true if value matches an existing topic ID" do
      expect(validator.valid_value?(topic.id)).to eq(true)
    end

    it "returns false if value does not match an existing topic ID" do
      expect(validator.valid_value?(1337)).to eq(false)
    end
  end
end
