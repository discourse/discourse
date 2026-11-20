# frozen_string_literal: true

describe Jobs::ResetRemovedUserLocales do
  it "clears removed choices and preserves choices that the site currently allows" do
    removed = Fabricate(:user, locale: "ja")
    restored = Fabricate(:user, locale: "fr")
    changed = Fabricate(:user, locale: "en")
    SiteSetting.default_locale = "en"
    SiteSetting.allowed_user_locales = "fr"

    described_class.new.execute(locales: %w[ja fr en])

    expect(removed.reload.locale).to be_nil
    expect(restored.reload.locale).to eq("fr")
    expect(changed.reload.locale).to eq("en")
  end
end
