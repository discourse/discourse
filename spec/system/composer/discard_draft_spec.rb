# frozen_string_literal: true

describe "Composer - discard draft modal", type: :system do
  fab!(:topic)
  fab!(:user) { Fabricate(:admin) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:discard_draft_modal) { PageObjects::Modals::DiscardDraft.new }

  before { sign_in(user) }

  context "when editing different post" do
    fab!(:post_1) { Fabricate(:post, topic:, user:) }
    fab!(:post_2) { Fabricate(:post, topic:, user:) }

    it "shows the discard modal when there are changes" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.fill_content("a b c d e f g")
      composer.minimize

      topic_page.click_post_action_button(post_2, :edit)

      expect(discard_draft_modal).to be_open
    end

    it "doesn't show the discard modal when there's no changes" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.minimize

      topic_page.click_post_action_button(post_2, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end
  end

  context "when editing the same post" do
    fab!(:post_1) { Fabricate(:post, topic:, user:) }

    it "doesn’t show the discard modal even if there are changes" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.fill_content("a b c d e f g")
      composer.minimize

      topic_page.click_post_action_button(post_1, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
      expect(composer).to have_content("a b c d e f g")

      composer.minimize
      expect(composer).to be_minimized

      topic_page.click_post_action_button(post_1, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end

    it "doesn’t show the discard modal when there's no changes" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.minimize

      topic_page.click_post_action_button(post_1, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end
  end

  context "when clicking abandon draft" do
    let(:dialog) { PageObjects::Components::Dialog.new }

    before { Jobs.run_immediately! }

    it "destroys draft" do
      visit "/new-topic"

      composer.fill_content("a b c d e f g")
      composer.close

      expect(discard_draft_modal).to be_open
      discard_draft_modal.click_save

      wait_for(timeout: 5) { Draft.last != nil }
      draft_key = Draft.last.draft_key

      visit "/new-topic"

      expect(dialog).to be_open
      expect(page).to have_content(I18n.t("js.drafts.abandon.confirm"))
      dialog.click_danger

      wait_for(timeout: 5) { Draft.find_by(draft_key: draft_key) == nil }
    end

    it "resumes draft when using /new-message" do
      visit "/new-message"

      composer.fill_content("a b c d e f g")
      composer.close

      expect(discard_draft_modal).to be_open
      discard_draft_modal.click_save

      visit "/new-message"

      expect(dialog).to be_open
      expect(page).to have_content(I18n.t("js.drafts.abandon.confirm"))
      dialog.click_button I18n.t("js.drafts.abandon.no_value")

      expect(composer).to be_opened
      expect(composer).to have_content("a b c d e f g")
    end
  end
end
