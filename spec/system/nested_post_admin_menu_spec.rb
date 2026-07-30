# frozen_string_literal: true

RSpec.describe "Nested view post admin menu" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
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
  let(:flag_modal) { PageObjects::Modals::Flag.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
  end

  def open_admin_menu_for(post)
    selector = "[data-post-number='#{post.post_number}']"
    page.execute_script(
      "document.querySelector(#{selector.to_json})?.scrollIntoView({ block: 'center', inline: 'nearest' })",
    )

    within(selector) do
      all(".show-more-actions", minimum: 0, wait: 0).first&.click
      find(".post-action-menu__admin").click
    end
  end

  def add_official_notice(post, raw)
    post.custom_fields[Post::NOTICE] = {
      type: Post.notices[:custom],
      raw: raw,
      cooked: PrettyText.cook(raw),
      created_by_user_id: admin.id,
    }
    post.save_custom_fields
  end

  def set_official_notice(raw)
    expect(page).to have_css(".change-post-notice-modal")
    find(".change-post-notice-modal textarea").fill_in(with: raw)
    find(".change-post-notice-modal .btn-primary").click
    expect(page).to have_no_css(".change-post-notice-modal")
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

    it "shows staff-only OP admin controls" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)

      expect(page).to have_css("[data-content][data-identifier='admin-post-menu'] .add-notice")
      expect(page).to have_css(
        "[data-content][data-identifier='admin-post-menu'] .toggle-post-type",
      )
    end

    it "applies staff color and official notice from the OP admin controls" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)
      find("[data-content][data-identifier='admin-post-menu'] .toggle-post-type").click

      expect(page).to have_css(
        "[data-post-number='#{op.post_number}'].moderator .nested-view__op-content.regular > .cooked",
        text: op.raw,
      )

      open_admin_menu_for(op)
      find("[data-content][data-identifier='admin-post-menu'] .add-notice").click
      set_official_notice("Official OP notice")

      expect(page).to have_css(
        "[data-post-number='#{op.post_number}'] .post-notice.custom",
        text: "Official OP notice",
      )
    end

    it "renders staff color and official notices on nested replies" do
      reply.update!(post_type: Post.types[:moderator_action])
      add_official_notice(reply, "Official reply notice")

      nested_view.visit_nested(topic)

      expect(page).to have_css(
        ".nested-post.moderator [data-post-number='#{reply.post_number}'] .nested-post__content.regular > .cooked",
        text: reply.raw,
      )
      expect(page).to have_css(
        "[data-post-number='#{reply.post_number}'] .post-notice.custom",
        text: "Official reply notice",
      )
    end

    it "opens the change-owner modal when clicking the admin menu item" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(reply)
      find("[data-content][data-identifier='admin-post-menu'] .change-owner").click

      expect(page).to have_css(".change-ownership-modal")
    end
  end

  context "as a regular user" do
    before do
      SiteSetting.post_menu = "like|copyLink|share|flag|edit|bookmark|delete|admin|reply"
      SiteSetting.post_menu_hidden_items = ""
      sign_in(flagger)
    end

    it "opens the flag modal from the OP menu" do
      nested_view.visit_nested(topic)

      within("[data-post-number='#{op.post_number}']") { find(".post-action-menu__flag").click }

      expect(flag_modal).to be_open
    end
  end
end
