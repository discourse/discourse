# frozen_string_literal: true

describe TagLocalization do
  fab!(:tag)

  describe "validations" do
    it "validates presence of name and locale" do
      localization = TagLocalization.new(tag:)

      expect(localization).not_to be_valid
      expect(localization.errors[:locale]).to be_present
      expect(localization.errors[:name]).to be_present
    end

    it "validates uniqueness of tag_id scoped to locale" do
      Fabricate(:tag_localization, tag:, locale: "ja")

      duplicate = TagLocalization.new(tag:, locale: "ja", name: "別名")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tag_id]).to be_present
    end

    it "allows same tag_id with different locale" do
      Fabricate(:tag_localization, tag:, locale: "ja")

      different_locale = TagLocalization.new(tag:, locale: "es", name: "Prueba")

      expect(different_locale).to be_valid
    end

    it "validates description length" do
      localization =
        TagLocalization.new(tag:, locale: "ja", name: "Test", description: ("a" * 1001))

      expect(localization).not_to be_valid
      expect(localization.errors[:description]).to be_present
    end
  end
end
