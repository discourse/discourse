# frozen_string_literal: true

RSpec.describe UserCustomField do
  describe ".searchable" do
    it "includes user_custom_fields with valid, searchable user_field references" do
      Fabricate(:user_field, id: 123, searchable: true)
      valid_user_custom_field = Fabricate(:user_custom_field, name: "user_field_123")

      result = UserCustomField.searchable

      expect(result).to include(valid_user_custom_field)
    end

    it "excludes user_custom_fields with non-searchable user_field references" do
      Fabricate(:user_field, id: 456, searchable: false)
      non_searchable_custom_field = Fabricate(:user_custom_field, name: "user_field_456")

      result = UserCustomField.searchable

      expect(result).not_to include(non_searchable_custom_field)
    end

    it "excludes user_custom_fields with invalid user_field references" do
      invalid_user_custom_field = Fabricate(:user_custom_field, name: "user_field_invalid")

      result = UserCustomField.searchable

      expect(result).not_to include(invalid_user_custom_field)
    end

    it "excludes user_custom_fields with unrelated names" do
      unrelated_custom_field = Fabricate(:user_custom_field, name: "cost_center")

      result = UserCustomField.searchable

      expect(result).not_to include(unrelated_custom_field)
    end
  end
end
