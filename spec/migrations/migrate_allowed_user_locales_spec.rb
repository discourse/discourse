# frozen_string_literal: true

require Rails.root.join("db/migrate/20261120035951_migrate_allowed_user_locales.rb")

describe MigrateAllowedUserLocales do
  it "preserves disabled language selection and leaves the old setting available" do
    SiteSetting.create!(name: "allow_user_locale", value: "f", data_type: 5)

    described_class.new.up

    expect(SiteSetting.find_by(name: "allowed_user_locales")).to have_attributes(
      value: "",
      data_type: 8,
    )
    expect(SiteSetting.find_by(name: "allow_user_locale").value).to eq("f")
  end

  it "preserves enabled language selection" do
    SiteSetting.create!(name: "allow_user_locale", value: "t", data_type: 5)

    described_class.new.up

    expect(SiteSetting.find_by(name: "allowed_user_locales")).to have_attributes(
      value: "all",
      data_type: 8,
    )
  end

  it "preserves an existing language selection when run again" do
    SiteSetting.create!(name: "allow_user_locale", value: "t", data_type: 5)
    described_class.new.up
    SiteSetting.find_by(name: "allowed_user_locales").update!(value: "fr|ja")

    described_class.new.up

    expect(SiteSetting.find_by(name: "allowed_user_locales").value).to eq("fr|ja")
  end

  it "does not create stored settings on a fresh install" do
    expect { described_class.new.up }.not_to change(SiteSetting, :count)
  end
end
