# frozen_string_literal: true

describe "Permanently delete" do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

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
      dialog.fill_in_confirmation_phrase(confirmation_phrase)
      dialog.click_danger

      expect(page).to have_no_css("#post_#{post.post_number}")
      expect(Post.unscoped.exists?(post.id)).to eq(false)
    end

    it "does not delete the post when cancelling" do
      topic_page.permanently_delete_post(post)
      dialog.click_no

      expect(dialog).to be_closed
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
      expect(dialog).to have_content("before permanently deleting this post")
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
      visit(topic.url)
    end

    it "permanently deletes the topic after confirmation" do
      topic_page.permanently_delete_post(first_post)
      dialog.fill_in_confirmation_phrase(confirmation_phrase)
      dialog.click_danger

      expect(page).to have_current_path("/")
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

      expect(dialog).to be_open
      dialog.fill_in_confirmation_phrase(confirmation_phrase)
      dialog.click_danger

      expect(page).to have_no_css("#post_#{post_with_revisions.post_number} .post-info.edits")
      expect(PostRevision.exists?(revision_id)).to eq(false)
    end
  end
end
