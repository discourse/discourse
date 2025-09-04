# frozen_string_literal: true

describe "Composer - Drafts", type: :system do
  fab!(:topic)
  fab!(:current_user, :admin)

  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:discard_draft_modal) { PageObjects::Modals::DiscardDraft.new }

  before { sign_in(current_user) }

  context "when clicking X (save and close)" do
    it "saves the draft and shows a toast" do
      visit "/new-topic"

      expect(composer).to be_opened
      composer.fill_title("this is a test topic")
      composer.fill_content("a b c d e f g")
      composer.close

      expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
      try_until_success { expect(Draft.where(user: current_user).count).to eq(1) }
    end

    context "when only a title and category is specified" do
      fab!(:category_1, :category)
      fab!(:category_2, :category)

      it "saves the draft and shows a toast" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_title("this is a test topic")
        composer.switch_category(category_1.name)
        composer.close

        expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))

        try_until_success { expect(Draft.where(user: current_user).count).to eq(1) }
      end
    end

    context "when only title is specified and it is too short" do
      it "does not save the draft or show a toast" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_title("test")
        composer.close
        expect(composer).to be_closed

        expect(toasts).to have_no_message
        expect(Draft.where(user: current_user).count).to eq(0)
      end
    end
  end

  context "when clicking discard" do
    let(:dialog) { PageObjects::Components::Dialog.new }

    before { Jobs.run_immediately! }

    it "does not show confirmation if there is no user input in the composer" do
      visit "/new-topic"

      expect(composer).to be_opened
      composer.discard

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_closed
    end

    it "destroys draft after discard confirmation" do
      visit "/new-topic"

      composer.fill_title("this is a test topic")
      composer.fill_content("a b c d e f g")

      try_until_success { expect(Draft.where(user: current_user).count).to eq(1) }

      composer.discard

      expect(discard_draft_modal).to be_open
      discard_draft_modal.click_discard

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_closed

      try_until_success { expect(Draft.where(user: current_user).count).to eq(0) }
    end

    context "when only a title and category is specified" do
      fab!(:category_1, :category)
      fab!(:category_2, :category)

      it "shows discard confirmation and allows saving the draft" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_title("this is a test topic")
        composer.switch_category(category_1.name)
        composer.discard

        expect(discard_draft_modal).to be_open
        discard_draft_modal.click_save

        expect(discard_draft_modal).to be_closed
        expect(composer).to be_closed

        try_until_success { expect(Draft.where(user: current_user).count).to eq(1) }
      end
    end
  end

  context "when editing different post" do
    fab!(:post_1) { Fabricate(:post, topic:, user: current_user) }
    fab!(:post_2) { Fabricate(:post, topic:, user: current_user) }

    it "shows the discard modal when there are changes in the composer" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.fill_content("a b c d e f g")
      composer.minimize

      topic_page.click_post_action_button(post_2, :edit)

      expect(discard_draft_modal).to be_open
    end

    it "doesn't show the discard modal when there are no changes in the composer" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.minimize

      topic_page.click_post_action_button(post_2, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end
  end

  context "when editing the same post" do
    fab!(:post_1) { Fabricate(:post, topic:, user: current_user) }

    it "doesn’t show the discard modal even if there are changes in the composer" do
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

    it "doesn’t show the discard modal when there are no changes in the composer" do
      topic_page.visit_topic(post_1.topic)
      topic_page.click_post_action_button(post_1, :edit)
      composer.minimize

      topic_page.click_post_action_button(post_1, :edit)

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end
  end
end
