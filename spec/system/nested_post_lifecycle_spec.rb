# frozen_string_literal: true

RSpec.describe "Nested view post lifecycle" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
  end

  describe "editing a post and saving" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: user, raw: "Original content before editing")
    end

    before { sign_in(user) }

    it "updates the post content after saving an edit" do
      nested_view.visit_nested(topic)
      expect(
        browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Original content before editing")],
        useInnerText: true,
      )

      nested_view.click_post_edit_button(root_reply)
      expect(composer).to be_opened

      composer.fill_content("Updated content after editing")
      composer.submit

      expect(composer).to be_closed
      expect(
        browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Updated content after editing")],
        useInnerText: true,
      )
      expect(nested_view).to have_nested_view
    end
  end

  describe "editing the OP and saving" do
    before { sign_in(user) }

    it "updates the OP content after saving an edit" do
      op.update!(raw: "Original OP content that should be long enough to pass")
      op.rebake!

      nested_view.visit_nested(topic)
      expect(
        browser_root.locator(".nested-view__op").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Original OP content that should be long enough to pass")],
        useInnerText: true,
      )

      nested_view.click_post_edit_button(op)
      expect(composer).to be_opened

      composer.fill_content("Updated OP content that should also be long enough")
      composer.submit

      expect(composer).to be_closed
      expect(
        browser_root.locator(".nested-view__op").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Updated OP content that should also be long enough")],
        useInnerText: true,
      )
    end
  end

  describe "deleting a post" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: user, raw: "Post that will be deleted")
    end

    context "when user deletes their own post" do
      before { sign_in(user) }

      it "shows a deleted placeholder after confirming deletion" do
        nested_view.visit_nested(topic)
        expect(
          browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Post that will be deleted")],
          useInnerText: true,
        )

        nested_view.click_post_delete_button(root_reply)
        dialog.click_yes

        expect(nested_view).to have_deleted_post_class_for(root_reply)
      end
    end

    context "when admin deletes a post" do
      before { sign_in(admin) }

      it "shows a deleted placeholder" do
        nested_view.visit_nested(topic)
        expect(
          browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Post that will be deleted")],
          useInnerText: true,
        )

        nested_view.click_post_delete_button(root_reply)
        dialog.click_yes

        expect(nested_view).to have_deleted_post_class_for(root_reply)
      end
    end
  end

  describe "deleting a post with children" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: user, raw: "Parent with children") }

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply content",
        reply_to_post_number: root_reply.post_number,
      )
    end

    before { sign_in(admin) }

    it "shows placeholder for parent but preserves children" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_post(root_reply)
      expect(nested_view).to have_post(child_reply)

      nested_view.click_post_delete_button(root_reply)
      dialog.click_yes

      expect(nested_view).to have_deleted_post_class_for(root_reply)
      expect(nested_view).to have_post(child_reply)
      expect(
        browser_root.locator("[data-post-number='#{child_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Child reply content")],
        useInnerText: true,
      )
    end
  end

  describe "recovering a deleted post" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: user, raw: "Post that was deleted and recovered")
    end

    before { sign_in(admin) }

    it "clears the deleted placeholder after recovery" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_post(root_reply)

      nested_view.click_post_delete_button(root_reply)
      dialog.click_yes
      expect(nested_view).to have_deleted_post_class_for(root_reply)

      nested_view.click_post_recover_button(root_reply)
      expect(nested_view).to have_no_deleted_placeholder_for(root_reply)
      expect(
        browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Post that was deleted and recovered")],
        useInnerText: true,
      )
    end
  end

  describe "staff viewing deleted post content" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: user, raw: "Secret deleted content here")
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "shows an eye button to toggle deleted content visibility" do
        nested_view.visit_nested(topic)
        expect(
          browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Secret deleted content here")],
          useInnerText: true,
        )

        nested_view.click_post_delete_button(root_reply)
        dialog.click_yes

        expect(nested_view).to have_deleted_post_class_for(root_reply)
        expect(nested_view).to have_toggle_deleted_content_button_for(root_reply)
        expect(nested_view).to have_no_deleted_content_visible_for(root_reply)

        nested_view.click_toggle_deleted_content(root_reply)

        expect(nested_view).to have_deleted_content_visible_for(root_reply)
        expect(
          browser_root.locator(".nested-post__placeholder-reveal").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Secret deleted content here")],
          useInnerText: true,
        )
      end

      it "hides deleted content when toggled again" do
        nested_view.visit_nested(topic)
        expect(
          browser_root.locator("[data-post-number='#{root_reply.post_number}']").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Secret deleted content here")],
          useInnerText: true,
        )

        nested_view.click_post_delete_button(root_reply)
        dialog.click_yes

        expect(nested_view).to have_deleted_post_class_for(root_reply)
        nested_view.click_toggle_deleted_content(root_reply)
        expect(nested_view).to have_deleted_content_visible_for(root_reply)

        nested_view.click_toggle_deleted_content(root_reply)
        expect(nested_view).to have_no_deleted_content_visible_for(root_reply)
      end
    end

    context "when logged in as regular user" do
      before { sign_in(user) }

      it "hides deleted root leaves" do
        root_reply.update!(deleted_at: Time.current)

        nested_view.visit_nested(topic)
        expect(nested_view).to have_no_post(root_reply)
      end
    end
  end

  describe "editing a child post" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root post") }

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: user,
        raw: "Original child content here",
        reply_to_post_number: root_reply.post_number,
      )
    end

    before { sign_in(user) }

    it "updates the child post content after saving" do
      nested_view.visit_nested(topic)
      expect(
        browser_root.locator("[data-post-number='#{child_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Original child content here")],
        useInnerText: true,
      )

      nested_view.click_post_edit_button(child_reply)
      expect(composer).to be_opened

      composer.fill_content("Updated child content here")
      composer.submit

      expect(composer).to be_closed
      expect(
        browser_root.locator("[data-post-number='#{child_reply.post_number}']").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Updated child content here")],
        useInnerText: true,
      )
    end
  end
end
