# frozen_string_literal: true

describe "Permanently delete" do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:confirm_modal) { PageObjects::Modals::PermanentlyDeleteConfirm.new }

  let(:confirmation_phrase) { I18n.t("js.post.controls.permanently_delete_confirm_phrase") }

  before { SiteSetting.can_permanently_delete = true }

  context "when permanently deleting a post" do
    before do
      PostDestroyer.new(other_admin, post).destroy
      sign_in(admin)
      topic_page.visit_topic(topic)
      expect(topic_page).to have_deleted_post(post)
    end

    it "permanently deletes the post after confirmation" do
      topic_page.permanently_delete_post(post)
      confirm_modal.fill_in_confirmation_phrase(confirmation_phrase)
      confirm_modal.click_danger

      expect(browser_root.locator("#post_#{post.post_number}").filter(visible: true)).to have_count(
        0,
      )
      expect(Post.unscoped.exists?(post.id)).to eq(false)
    end

    it "does not delete the post when cancelling" do
      topic_page.permanently_delete_post(post)
      confirm_modal.cancel

      expect(confirm_modal).to be_closed
      expect(topic_page).to have_deleted_post(post)
      expect(Post.unscoped.exists?(post.id)).to eq(true)
    end
  end

  context "when the same admin tries to permanently delete too soon" do
    before do
      PostDestroyer.new(admin, post).destroy
      sign_in(admin)
      topic_page.visit_topic(topic)
      expect(topic_page).to have_deleted_post(post)
    end

    it "shows a cooldown message instead of the confirmation dialog" do
      topic_page.permanently_delete_post(post)

      expect(dialog).to be_open
      expect(dialog).to have_displayed_content("before permanently deleting this post")
      dialog.click_ok
      expect(Post.with_deleted.exists?(post.id)).to eq(true)
    end
  end

  context "when permanently deleting a topic via first post" do
    fab!(:first_post) { topic.first_post }

    before do
      PostDestroyer.new(other_admin, post).destroy
      PostDestroyer.new(other_admin, first_post).destroy
      sign_in(admin)
      browser_page.goto(topic.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
    end

    it "permanently deletes the topic after confirmation" do
      topic_page.permanently_delete_post(first_post)
      confirm_modal.fill_in_confirmation_phrase(confirmation_phrase)
      confirm_modal.click_danger

      expect(browser_page).to have_url("/")
      expect(Topic.unscoped.exists?(topic.id)).to eq(false)
    end
  end

  context "when permanently deleting post revisions" do
    fab!(:post_with_revisions) { Fabricate(:post, topic:, user: admin, version: 2) }
    fab!(:revision) do
      Fabricate(
        :post_revision,
        post: post_with_revisions,
        user: admin,
        number: 2,
        modifications: {
          "raw" => %w[original edited],
        },
      )
    end

    let(:post_history_modal) { PageObjects::Modals::PostHistory.new }

    before do
      sign_in(admin)
      topic_page.visit_topic(topic)
    end

    it "permanently deletes revisions after confirmation" do
      revision_id = revision.id

      topic_page.open_post_history(post_with_revisions)
      expect(post_history_modal).to be_open

      post_history_modal.hide_revision
      expect(post_history_modal).to have_destroy_revisions_button
      post_history_modal.destroy_revisions

      expect(confirm_modal).to be_open
      confirm_modal.fill_in_confirmation_phrase(confirmation_phrase)
      confirm_modal.click_danger

      expect(
        browser_root.locator("#post_#{post_with_revisions.post_number} .post-info.edits").filter(
          visible: true,
        ),
      ).to have_count(0)
      expect(PostRevision.exists?(revision_id)).to eq(false)
    end
  end
end
