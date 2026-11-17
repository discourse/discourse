# frozen_string_literal: true

RSpec.describe "Checklist toggles" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user:) }
  fab!(:post) { Fabricate(:post, topic:, user:, raw: "- [ ] first") }

  let(:checklist) { PageObjects::Components::CookedChecklist.new }

  before do
    SiteSetting.checklist_enabled = true
    sign_in(user)
  end

  it "hydrates raw and toggles a checklist from the topic stream" do
    page.visit "/t/#{topic.slug}/#{topic.id}"

    checklist.click_checkbox

    expect(checklist).to have_saved_checked

    page.refresh

    expect(checklist).to have_saved_checked
  end
end
