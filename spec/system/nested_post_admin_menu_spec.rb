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
    browser_page.evaluate(
      "function(arguments) { #{"document.querySelector(#{selector.to_json})?.scrollIntoView({ block: 'center', inline: 'nearest' })"} }",
      arg: [],
    )

    within_browser(selector) do
      browser_root.locator(".show-more-actions").filter(visible: true).all.first&.click
      browser_root.locator(".post-action-menu__admin").filter(visible: true).click
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
    expect(
      browser_root.locator(".change-post-notice-modal").filter(visible: true),
    ).not_to have_count(0)
    browser_root.locator(".change-post-notice-modal textarea").filter(visible: true).fill(raw)
    browser_root.locator(".change-post-notice-modal .btn-primary").filter(visible: true).click
    expect(browser_root.locator(".change-post-notice-modal").filter(visible: true)).to have_count(0)
  end

  context "as an admin" do
    before { sign_in(admin) }

    it "fires lockPost when clicking the admin menu item on a reply" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(reply)
      expect(
        browser_root.locator("[data-content][data-identifier='admin-post-menu']").filter(
          visible: true,
        ),
      ).not_to have_count(0)
      browser_root
        .locator("[data-content][data-identifier='admin-post-menu'] .lock-post")
        .filter(visible: true)
        .click

      try_until_success { expect(reply.reload.locked_by_id).to eq(admin.id) }
    end

    it "fires lockPost when clicking the admin menu item on the OP" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)
      expect(
        browser_root.locator("[data-content][data-identifier='admin-post-menu']").filter(
          visible: true,
        ),
      ).not_to have_count(0)
      browser_root
        .locator("[data-content][data-identifier='admin-post-menu'] .lock-post")
        .filter(visible: true)
        .click

      try_until_success { expect(op.reload.locked_by_id).to eq(admin.id) }
    end

    it "shows staff-only OP admin controls" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)

      expect(
        browser_root.locator(
          "[data-content][data-identifier='admin-post-menu'] .add-notice",
        ).filter(visible: true),
      ).not_to have_count(0)
      expect(
        browser_root.locator(
          "[data-content][data-identifier='admin-post-menu'] .toggle-post-type",
        ).filter(visible: true),
      ).not_to have_count(0)
    end

    it "applies staff color and official notice from the OP admin controls" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(op)
      browser_root
        .locator("[data-content][data-identifier='admin-post-menu'] .toggle-post-type")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(
          "[data-post-number='#{op.post_number}'].moderator .nested-view__op-content.regular > .cooked",
        ).filter(visible: true),
      ).to contain_text([browser_text_pattern(op.raw)], useInnerText: true)

      open_admin_menu_for(op)
      browser_root
        .locator("[data-content][data-identifier='admin-post-menu'] .add-notice")
        .filter(visible: true)
        .click
      set_official_notice("Official OP notice")

      expect(
        browser_root.locator("[data-post-number='#{op.post_number}'] .post-notice.custom").filter(
          visible: true,
        ),
      ).to contain_text([browser_text_pattern("Official OP notice")], useInnerText: true)
    end

    it "renders staff color and official notices on nested replies" do
      reply.update!(post_type: Post.types[:moderator_action])
      add_official_notice(reply, "Official reply notice")

      nested_view.visit_nested(topic)

      expect(
        browser_root.locator(
          ".nested-post.moderator [data-post-number='#{reply.post_number}'] .nested-post__content.regular > .cooked",
        ).filter(visible: true),
      ).to contain_text([browser_text_pattern(reply.raw)], useInnerText: true)
      expect(
        browser_root.locator(
          "[data-post-number='#{reply.post_number}'] .post-notice.custom",
        ).filter(visible: true),
      ).to contain_text([browser_text_pattern("Official reply notice")], useInnerText: true)
    end

    it "opens the change-owner modal when clicking the admin menu item" do
      nested_view.visit_nested(topic)
      open_admin_menu_for(reply)
      browser_root
        .locator("[data-content][data-identifier='admin-post-menu'] .change-owner")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".change-ownership-modal").filter(visible: true),
      ).not_to have_count(0)
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

      within_browser(
        browser_root.locator("[data-post-number='#{op.post_number}']").filter(visible: true),
      ) { browser_root.locator(".post-action-menu__flag").filter(visible: true).click }

      expect(flag_modal).to be_open
    end
  end
end
