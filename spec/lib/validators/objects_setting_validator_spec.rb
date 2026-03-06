# frozen_string_literal: true

RSpec.describe ObjectsSettingValidator do
  let(:schema) { { name: "test", properties: { title: { type: "string", required: true } } } }

  describe "#valid_value?" do
    it "returns true for valid objects" do
      validator = ObjectsSettingValidator.new(schema: schema)
      expect(validator.valid_value?('[{"title": "hello"}]')).to eq(true)
      expect(validator.error_message).to be_nil
    end

    it "returns false with specific error message for invalid objects" do
      validator = ObjectsSettingValidator.new(schema: schema)
      expect(validator.valid_value?("[{}]")).to eq(false)
      expect(validator.error_message).to include("must be present")
    end
  end
end
