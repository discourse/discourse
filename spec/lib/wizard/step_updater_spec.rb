# frozen_string_literal: true

RSpec.describe Wizard::StepUpdater do
  before { SiteSetting.wizard_enabled = true }

  fab!(:user, :admin)
  let(:wizard) { Wizard::Builder.new(user).build }

  describe "setup" do
    it "updates the setup step with all fields" do
      updater =
        wizard.create_updater(
          "setup",
          title: "new forum title",
          default_locale: "ru",
          login_required: "public",
          invite_only: "sign_up",
          must_approve_users: "no",
        )
      updater.update

      expect(updater.success?).to eq(true)
      expect(SiteSetting.title).to eq("new forum title")
      expect(SiteSetting.login_required?).to eq(false)
      expect(SiteSetting.invite_only?).to eq(false)
      expect(SiteSetting.must_approve_users?).to eq(false)
      expect(SiteSetting.default_locale).to eq("ru")
      expect(wizard.completed_steps?("setup")).to eq(true)
    end

    it "won't allow updates to the default value when required" do
      updater =
        wizard.create_updater(
          "setup",
          title: SiteSetting.title,
          login_required: "public",
          invite_only: "sign_up",
          must_approve_users: "no",
        )
      updater.update

      expect(updater.success?).to eq(false)
    end

    it "updates privacy settings to private correctly" do
      updater =
        wizard.create_updater(
          "setup",
          title: "new forum title",
          login_required: "private",
          invite_only: "invite_only",
          must_approve_users: "yes",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(SiteSetting.login_required?).to eq(true)
      expect(SiteSetting.invite_only?).to eq(true)
      expect(SiteSetting.must_approve_users?).to eq(true)
      expect(wizard.completed_steps?("setup")).to eq(true)
    end
  end
end
