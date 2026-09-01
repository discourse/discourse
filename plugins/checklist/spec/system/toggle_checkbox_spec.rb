# frozen_string_literal: true

RSpec.describe "Checklist toggles" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user:) }
  fab!(:post) { Fabricate(:post, topic:, user:, raw: "- [ ] first") }

  before do
    SiteSetting.checklist_enabled = true
    sign_in(user)
  end

  it "hydrates raw and toggles a checklist from the topic stream" do
    page.visit "/t/#{topic.slug}/#{topic.id}"

    find(".chcklst-box").click

    expect(page).to have_css(".chcklst-box.checked")
    expect(page).to have_no_css(".chcklst-box.is-saving")
    expect(post.reload.raw).to eq("- [x] first")
  end
end
