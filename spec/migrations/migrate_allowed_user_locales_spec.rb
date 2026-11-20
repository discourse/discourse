# frozen_string_literal: true

require Rails.root.join("db/migrate/20261120151031_migrate_allowed_user_locales")

describe MigrateAllowedUserLocales do
  def stored_policy
    SiteSetting.where(name: "allowed_user_locales").pick(:value)
  end

  it "copies only the disabled choice and preserves existing preferences and overrides" do
    user = Fabricate(:user, locale: "ja")
    migration = described_class.new

    migration.up
    expect(stored_policy).to be_nil

    SiteSetting.create!(name: "allow_user_locale", value: "t", data_type: 5)
    migration.up
    expect(stored_policy).to be_nil

    SiteSetting.where(name: "allow_user_locale").update_all(value: "f")
    migration.up
    expect(stored_policy).to eq("none")
    expect(user.reload.locale).to eq("ja")

    SiteSetting.where(name: "allowed_user_locales").update_all(value: "fr")
    migration.up
    expect(stored_policy).to eq("fr")
  end
end
