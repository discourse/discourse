# frozen_string_literal: true

RSpec.describe "i18n integrity checks" do
  def extract_locale(path)
    path[/\.([^.]{2,})\.yml$/, 1]
  end

  def load_yaml(path)
    YAML.load_file(path, aliases: true)
  end

  it "has an i18n key for each Site Setting" do
    SiteSetting.all_settings.each do |s|
      next if s[:plugin] == SiteSetting::SAMPLE_TEST_PLUGIN.name
      expect(s[:description]).not_to be_blank
    end
  end

  it "has an i18n key for each Badge description" do
    Badge
      .where(system: true)
      .each do |b|
        expect(b.long_description).to be_present
        expect(b.description).to be_present
      end
  end

  it "has an admin_js namespace in client locale files without a fallback locale",
     :aggregate_failures do
    Dir[Rails.root.join("config/locales/client.*.yml")].each do |path|
      locale = extract_locale(path)
      next if LocaleSiteSetting.fallback_locale(locale)

      expect(load_yaml(path).dig(locale, "admin_js")).to be, "#{path}: missing admin_js namespace"
    end
  end
end

RSpec.describe "fallbacks" do
  before do
    I18n.backend = I18n::Backend::DiscourseI18n.new
    I18n.fallbacks = I18n::Backend::FallbackLocaleList.new
    I18n.reload!
    I18n.init_accelerator!
  end

  it "finds the fallback translation" do
    I18n.backend.store_translations(:en, test: "en test")

    I18n.with_locale("pl_PL") { expect(I18n.t("test")).to eq("en test") }
  end

  context "when in a multi-threaded environment" do
    it "finds the fallback translation" do
      I18n.backend.store_translations(:en, test: "en test")

      thread = Thread.new { I18n.with_locale("pl_PL") { expect(I18n.t("test")).to eq("en test") } }

      begin
        thread.join
      ensure
        thread.exit
      end
    end
  end
end
