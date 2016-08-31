require 'rails_helper'
require_dependency 'wizard/step_updater'

describe Wizard::StepUpdater do
  let(:user) { Fabricate(:admin) }

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

      expect(updater.success?).to eq(true)
      expect(SiteSetting.contact_email).to eq("eviltrout@example.com")
      expect(SiteSetting.contact_url).to eq("http://example.com/custom-contact-url")
      expect(SiteSetting.site_contact_username).to eq(user.username)
    end

    it "doesn't update when there are errors" do
      updater.update(contact_email: 'not-an-email',
                     site_contact_username: 'not-a-username')
      expect(updater.success?).to eq(false)
      expect(updater.errors).to be_present
    end
  end

end
