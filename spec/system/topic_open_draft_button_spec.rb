# frozen_string_literal: true

RSpec.describe "Topic footer shows 'Open Draft' when draft exists", type: :system do
  fab!(:post)
  let(:topic) { post.topic }
  let!(:second_post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:user) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(current_user) }

  it "changes the reply button label and tooltip for footer and post reply buttons, persists on reload" do
    # Visit topic and verify initial footer label and tooltip are for Reply
    topic_page.visit_topic(topic)
    footer_button = find("#topic-footer-buttons .create")
    expect(footer_button[:title]).to eq(I18n.t("js.topic.reply.help"))
    expect(footer_button).to have_text(I18n.t("js.topic.reply.title"))

    # Verify initial post-level reply button tooltip/label
    post_button = find(".post-action-menu__reply", match: :first)
    expect(post_button[:title]).to eq(I18n.t("js.post.controls.reply"))
    expect(post_button).to have_text(I18n.t("js.topic.reply.title"))

    # Start a reply and then save-and-close to create a draft
    topic_page.click_reply_button
    composer.fill_content("this is a draft reply")
    composer.close

    # Wait for draft saved toast as confirmation
    expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))

    # The footer reply button label and tooltip should become "Open Draft"
    try_until_success do
      footer_button = find("#topic-footer-buttons .create")
      expect(footer_button[:title]).to eq(I18n.t("js.topic.open_draft_help"))
      expect(footer_button).to have_text(I18n.t("js.topic.open_draft"))
    end

    # Post-level reply buttons should remain as Reply for topic-level draft
    try_until_success do
      post_button = find(".post-action-menu__reply", match: :first)
      expect(post_button[:title]).to eq(I18n.t("js.post.controls.reply"))
      expect(post_button).to have_text(I18n.t("js.topic.reply.title"))
    end

    # Reload and ensure the labels/tooltips persist
    visit(current_path)
    try_until_success do
      footer_button = find("#topic-footer-buttons .create")
      expect(footer_button[:title]).to eq(I18n.t("js.topic.open_draft_help"))
      expect(footer_button).to have_text(I18n.t("js.topic.open_draft"))
    end
    try_until_success do
      post_button = find(".post-action-menu__reply", match: :first)
      expect(post_button[:title]).to eq(I18n.t("js.post.controls.reply"))
      expect(post_button).to have_text(I18n.t("js.topic.reply.title"))
    end
  end

  it "scopes post-level Open Draft label to the correct post only" do
    topic_page.visit_topic(topic)

    # Open reply on second post, save-and-close
    topic_page.click_post_action_button(second_post, :reply)
    composer.fill_content("reply to second post")
    composer.close

    expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))

    # Only second post shows Open Draft
    try_until_success do
      within(topic_page.post_by_number_selector(second_post.post_number)) do
        btn = find(".post-action-menu__reply")
        expect(btn[:title]).to eq(I18n.t("js.post.controls.open_draft"))
        expect(btn).to have_text(I18n.t("js.topic.open_draft"))
      end

      within(topic_page.post_by_number_selector(post.post_number)) do
        btn = find(".post-action-menu__reply")
        expect(btn[:title]).to eq(I18n.t("js.post.controls.reply"))
        expect(btn).to have_text(I18n.t("js.topic.reply.title"))
      end
    end
  end
end
