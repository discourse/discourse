# frozen_string_literal: true

RSpec.describe ThemeSettingsMigration do
  describe "Validations" do
    subject(:badge) { Fabricate.build(:theme_settings_migration) }

    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:theme_field_id) }

    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:diff) }
  end
end
