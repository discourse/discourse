# frozen_string_literal: true

describe SiteSetting, ".allowed_user_locales" do
  it "allows all installed languages by default" do
    expect(SiteSetting.allowed_user_locales).to eq("all")
    expect(SiteSetting.allowed_user_locale_values).to contain_exactly(
      *LocaleSiteSetting.supported_locales,
    )
  end

  it "includes the site default without changing the installed locales" do
    SiteSetting.allowed_user_locales = "fr|ja"
    expect(SiteSetting.allowed_user_locale_values).to contain_exactly("en", "fr", "ja")
    expect(JSON.parse(SiteSetting.available_locales).map { |locale| locale["value"] }).to include(
      "de",
    )
  end

  it "rejects unknown language codes" do
    expect { SiteSetting.allowed_user_locales = "fr|猫" }.to raise_error(
      Discourse::InvalidParameters,
    )
  end
end
