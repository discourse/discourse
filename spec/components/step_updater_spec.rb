require 'rails_helper'
require_dependency 'wizard/step_updater'

describe Wizard::StepUpdater do
  let(:user) { Fabricate(:admin) }

  context "locale" do
    let(:updater) { Wizard::StepUpdater.new(user, 'locale') }

    it "does not require refresh when the language stays the same" do
      updater.update(default_locale: 'en')
      expect(updater.refresh_required?).to eq(false)
    end

    it "updates the locale and requires refresh when it does change" do
      updater.update(default_locale: 'ru')
      expect(SiteSetting.default_locale).to eq('ru')
      expect(updater.refresh_required?).to eq(true)
    end
  end

  it "updates the locale" do
  end

  it "updates the forum title step" do
    updater = Wizard::StepUpdater.new(user, 'forum_title')
    updater.update(title: 'new forum title', site_description: 'neat place')

    expect(updater.success?).to eq(true)
    expect(SiteSetting.title).to eq("new forum title")
    expect(SiteSetting.site_description).to eq("neat place")
  end

  context "contact step" do
    let(:updater) { Wizard::StepUpdater.new(user, 'contact') }

    it "updates the fields correctly" do
      updater.update(contact_email: 'eviltrout@example.com',
                     contact_url: 'http://example.com/custom-contact-url',
                     site_contact_username: user.username)

      expect(updater).to be_success
      expect(SiteSetting.contact_email).to eq("eviltrout@example.com")
      expect(SiteSetting.contact_url).to eq("http://example.com/custom-contact-url")
      expect(SiteSetting.site_contact_username).to eq(user.username)
    end

    it "doesn't update when there are errors" do
      updater.update(contact_email: 'not-an-email',
                     site_contact_username: 'not-a-username')
      expect(updater).to_not be_success
      expect(updater.errors).to be_present
    end
  end

  context "colors step" do
    let(:updater) { Wizard::StepUpdater.new(user, 'colors') }

    context "with an existing color scheme" do
      let!(:color_scheme) { Fabricate(:color_scheme, name: 'existing', via_wizard: true) }

      it "updates the scheme" do
        updater.update(color_scheme: 'dark')
        expect(updater.success?).to eq(true)

        color_scheme.reload
        expect(color_scheme).to be_enabled

      end
    end

    context "without an existing scheme" do

      it "creates the scheme" do
        updater.update(color_scheme: 'dark')
        expect(updater.success?).to eq(true)

        color_scheme = ColorScheme.where(via_wizard: true).first
        expect(color_scheme).to be_present
        expect(color_scheme).to be_enabled
        expect(color_scheme.colors).to be_present
      end
    end
  end

end
