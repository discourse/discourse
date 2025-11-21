# frozen_string_literal: true

describe "Composer - Drafts", type: :system do
  fab!(:topic, :topic_with_op)
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
      expect(Draft.where(user: current_user).count).to eq(1)
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
        expect(Draft.where(user: current_user).count).to eq(1)
      end
    end

    context "when only title is specified and it is less than min_topic_title_length" do
      it "does saves the draft and shows a toast" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_title("x")
        composer.close
        expect(composer).to be_closed

        expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
        expect(Draft.where(user: current_user).count).to eq(1)
      end
    end

    context "when only body is specified and it is less than min_post_length" do
      it "does saves the draft and shows a toast" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_content("x")
        composer.close
        expect(composer).to be_closed

        expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
        expect(Draft.where(user: current_user).count).to eq(1)
      end
    end

    context "for an existing draft in a topic" do
      fab!(:draft) do
        Fabricate(
          :draft,
          topic:,
          user: current_user,
          reply: "This is an existing reply draft I want to save",
        )
      end

      it "opens the draft when clicking Reply and saves changes clicking X" do
        topic_page.visit_topic_and_open_composer(topic)

        expect(composer).to have_content("This is an existing reply draft I want to save")

        composer.fill_content("This is an updated reply content")
        composer.close
        expect(composer).to be_closed

        expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))

        draft.reload
        expect(JSON.parse(draft.data)["reply"]).to eq("This is an updated reply content")
      end

      it "does not save changes if nothing changed after opening the reply" do
        topic_page.visit_topic_and_open_composer(topic)

        expect(composer).to have_content("This is an existing reply draft I want to save")
        composer.close
        expect(toasts).to have_no_message
        expect(composer).to be_closed

        draft.reload
        expect(JSON.parse(draft.data)["reply"]).to eq(
          "This is an existing reply draft I want to save",
        )
      end
    end

    context "when starting a new reply draft in a topic" do
      it "saves a quote by itself when clicking X" do
        topic_page.visit_topic(topic)

        select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)
        topic_page.insert_quote_button.click

        expect(composer).to be_opened
        expect(composer).to have_value(<<~QUOTE.chomp)
    [quote=\"#{topic.first_post.user.username}, post:1, topic:#{topic.id}\"]\nHello worl\n[/quote]\n\n
    QUOTE
        composer.close
        expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
        expect(composer).to be_closed
        expect(Draft.where(user: current_user).count).to eq(1)
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

      try_until_success(reason: "Relies on an Ember debounce to update the draft") do
        expect(Draft.where(user: current_user).count).to eq(1)
      end

      composer.discard

      expect(discard_draft_modal).to be_open
      discard_draft_modal.click_discard

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_closed
      expect(Draft.where(user: current_user).count).to eq(0)
    end

    context "when only a title and category is specified" do
      fab!(:category_1, :category)
      fab!(:category_2, :category)

      it "shows Discard draft confirmation modal and hides it on Cancel button click" do
        visit "/new-topic"

        expect(composer).to be_opened
        composer.fill_title("this is a test topic")
        composer.switch_category(category_1.name)
        composer.discard

        expect(discard_draft_modal).to be_open
        discard_draft_modal.click_cancel

        expect(discard_draft_modal).to be_closed
      end
    end

    context "when opening a reply draft" do
      fab!(:draft) do
        Fabricate(:draft, topic:, user: current_user, reply: "This is a reply I started typing")
      end

      it "shows Discard draft confirmation modal and hides it on Cancel button click" do
        topic_page.visit_topic_and_open_composer(topic)

        expect(composer).to have_content("This is a reply I started typing")

        composer.discard

        expect(discard_draft_modal).to be_open
        discard_draft_modal.click_cancel

        expect(discard_draft_modal).to be_closed
      end

      it "discards the draft via the confirmation modal" do
        topic_page.visit_topic_and_open_composer(topic)

        expect(composer).to have_content("This is a reply I started typing")

        composer.discard

        expect(discard_draft_modal).to be_open
        discard_draft_modal.click_discard

        expect(discard_draft_modal).to be_closed
        expect(composer).to be_closed
        expect(Draft.where(user: current_user).count).to eq(0)
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

  context "when replying to a different topic with an active draft" do
    fab!(:other_topic, :topic_with_op)

    let(:topic_reply_choice_dialog) { PageObjects::Components::TopicReplyChoiceDialog.new }
    let(:topic_list) { PageObjects::Components::TopicList.new }

    before do
      topic.first_post.update!(raw: "This is the original topic OP content.")
      topic.first_post.rebake!

      other_topic.first_post.update!(raw: "This is the other topic OP content.")
      other_topic.first_post.rebake!
    end

    def visit_topic_and_save_draft
      topic_page.visit_topic_and_open_composer(topic)

      composer.fill_content("a b c d e f g")

      composer.close

      expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
      expect(Draft.where(user: current_user).count).to eq(1)

      topic_page.visit_topic(topic)
      topic_page.click_reply_button

      expect(composer).to be_opened
      expect(composer).to have_content("a b c d e f g")
    end

    context "when clicking the original topic in the topic reply choice dialog" do
      it "replies with the current content to the original topic" do
        visit_topic_and_save_draft

        # We have to navigate by clicking through the app to keep the
        # composer open.
        click_logo
        expect(topic_list).to have_topic(other_topic)
        topic_list.visit_topic(other_topic)

        expect(topic_page).to have_post_content(
          post_number: 1,
          content: "This is the other topic OP content.",
        )

        composer.create

        expect(topic_reply_choice_dialog).to be_open
        expect(topic_reply_choice_dialog).to have_reply_on_original_topic(topic)
        topic_reply_choice_dialog.click_reply_on_original

        expect(topic_reply_choice_dialog).to be_closed
        expect(composer).to be_closed

        expect(topic_page).to have_post_content(
          post_number: 1,
          content: "This is the original topic OP content.",
        )
        expect(topic_page).to have_post_content(post_number: 2, content: "a b c d e f g")
        expect(topic.reload.posts.last.raw).to eq("a b c d e f g")
      end
    end

    context "when clicking the new topic in the topic reply choice dialog" do
      it "replies with the current content to the new topic" do
        visit_topic_and_save_draft

        # We have to navigate by clicking through the app to keep the
        # composer open.
        click_logo
        expect(topic_list).to have_topic(other_topic)
        topic_list.visit_topic(other_topic)

        expect(topic_page).to have_post_content(
          post_number: 1,
          content: "This is the other topic OP content.",
        )

        composer.create

        expect(topic_reply_choice_dialog).to be_open
        expect(topic_reply_choice_dialog).to have_reply_here_topic(other_topic)
        topic_reply_choice_dialog.click_reply_here

        expect(topic_reply_choice_dialog).to be_closed
        expect(composer).to be_closed

        expect(topic_page).to have_post_content(
          post_number: 1,
          content: "This is the other topic OP content.",
        )
        expect(topic_page).to have_post_content(post_number: 2, content: "a b c d e f g")
        expect(other_topic.reload.posts.last.raw).to eq("a b c d e f g")
      end
    end

    context "when clicking Cancel in the topic reply choice dialog" do
      it "saves the current draft and will save future changes to the draft" do
        visit_topic_and_save_draft

        # We have to navigate by clicking through the app to keep the
        # composer open.
        click_logo
        expect(topic_list).to have_topic(other_topic)
        topic_list.visit_topic(other_topic)

        expect(topic_page).to have_post_content(
          post_number: 1,
          content: "This is the other topic OP content.",
        )

        composer.create

        expect(topic_reply_choice_dialog).to be_open
        topic_reply_choice_dialog.click_cancel
        expect(topic_reply_choice_dialog).to be_closed

        composer.fill_content("This is my updated draft content, wow very impressive.")

        try_until_success(reason: "Relies on waiting a few seconds for the draft to autosave") do
          draft = Draft.where(user: current_user).first
          expect(JSON.parse(draft.data)["reply"]).to eq(
            "This is my updated draft content, wow very impressive.",
          )
        end
      end
    end
  end
end
