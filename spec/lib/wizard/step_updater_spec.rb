# frozen_string_literal: true

RSpec.describe Wizard::StepUpdater do
  before { SiteSetting.wizard_enabled = true }

  fab!(:user) { Fabricate(:admin) }
  let(:wizard) { Wizard::Builder.new(user).build }

  describe "introduction" do
    it "updates the introduction step" do
      locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE
      updater =
        wizard.create_updater(
          "introduction",
          title: "new forum title",
          site_description: "neat place",
          default_locale: locale,
        )
      updater.update

      expect(updater.success?).to eq(true)
      expect(SiteSetting.title).to eq("new forum title")
      expect(SiteSetting.site_description).to eq("neat place")
      expect(updater.refresh_required?).to eq(false)
      expect(wizard.completed_steps?("introduction")).to eq(true)
    end

    it "updates the locale and requires refresh when it does change" do
      updater = wizard.create_updater("introduction", default_locale: "ru")
      updater.update
      expect(SiteSetting.default_locale).to eq("ru")
      expect(updater.refresh_required?).to eq(true)
      expect(wizard.completed_steps?("introduction")).to eq(true)
    end

    it "won't allow updates to the default value, when required" do
      updater =
        wizard.create_updater(
          "introduction",
          title: SiteSetting.title,
          site_description: "neat place",
        )
      updater.update

      expect(updater.success?).to eq(false)
    end
  end

  describe "privacy" do
    it "updates to open correctly" do
      updater =
        wizard.create_updater(
          "privacy",
          login_required: "public",
          invite_only: "sign_up",
          must_approve_users: "no",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(SiteSetting.login_required?).to eq(false)
      expect(SiteSetting.invite_only?).to eq(false)
      expect(SiteSetting.must_approve_users?).to eq(false)
      expect(wizard.completed_steps?("privacy")).to eq(true)
    end

    it "updates to private correctly" do
      updater =
        wizard.create_updater(
          "privacy",
          login_required: "private",
          invite_only: "invite_only",
          must_approve_users: "yes",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(SiteSetting.login_required?).to eq(true)
      expect(SiteSetting.invite_only?).to eq(true)
      expect(SiteSetting.must_approve_users?).to eq(true)
      expect(wizard.completed_steps?("privacy")).to eq(true)
    end
  end
end
