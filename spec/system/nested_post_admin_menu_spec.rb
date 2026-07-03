# frozen_string_literal: true

RSpec.describe "Nested view post admin menu" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) do
    Fabricate(
      :post,
      topic: topic,
      user: user,
      post_number: 1,
      raw: "Original OP content that is long enough to render",
    )
  end
  fab!(:reply) { Fabricate(:post, topic: topic, user: user, raw: "Some reply body here") }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
  end

  def open_admin_menu_for(post)
    selector = "[data-post-number='#{post.post_number}']"
    within(selector) do
      find(".show-more-actions").click if has_css?(".show-more-actions", wait: 2)
      find(".post-action-menu__admin").click
    end
  end

  context "as an admin" do
    before { sign_in(admin) }

    it "fires lockPost when clicking the admin menu item on a reply" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(reply)
      expect(page).to have_css("[data-content][data-identifier='admin-post-menu']")
      find("[data-content][data-identifier='admin-post-menu'] .lock-post").click

      try_until_success { expect(reply.reload.locked_by_id).to eq(admin.id) }
    end

    it "fires lockPost when clicking the admin menu item on the OP" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)
      expect(page).to have_css("[data-content][data-identifier='admin-post-menu']")
      find("[data-content][data-identifier='admin-post-menu'] .lock-post").click

      try_until_success { expect(op.reload.locked_by_id).to eq(admin.id) }
    end

    it "opens the change-owner modal when clicking the admin menu item" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(reply)
      find("[data-content][data-identifier='admin-post-menu'] .change-owner").click

      expect(page).to have_css(".change-ownership-modal")
    end
  end
end
