# frozen_string_literal: true

describe "Composer - Resuming an edit draft" do
  fab!(:current_user, :admin)
  fab!(:topic, :topic_with_op)
  fab!(:post_1) { Fabricate(:post, topic:, user: current_user, raw: "original post content") }
  fab!(:post_2) { Fabricate(:post, topic:, user: current_user, raw: "another post content") }

  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(current_user) }

  def save_edit_draft
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(post_1, :edit)
    composer.fill_content("edited post content")
    composer.close

    expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
    expect(composer).to be_closed
  end

  def expect_resumed_edit
    expect(composer).to be_opened
    expect(composer).to have_content("edited post content")
    expect(composer.button_label).to have_text(I18n.t("js.composer.save_edit"))
  end

  it "resumes the edit when clicking reply" do
    save_edit_draft
    topic_page.click_reply_button

    expect_resumed_edit

    composer.create

    expect(composer).to be_closed
    expect(topic_page).to have_post_content(
      post_number: post_1.post_number,
      content: "edited post content",
    )
    expect(post_1.reload.raw).to eq("edited post content")
  end

  it "resumes the edit when clicking edit on the same post" do
    save_edit_draft
    topic_page.click_post_action_button(post_1, :edit)

    expect_resumed_edit
  end

  it "starts a fresh edit when clicking edit on a different post" do
    save_edit_draft
    topic_page.click_post_action_button(post_2, :edit)

    expect(composer).to be_opened
    expect(composer).to have_content("another post content")
  end

  it "resumes the edit when revisiting the topic" do
    save_edit_draft
    topic_page.visit_topic(topic)

    expect_resumed_edit
  end
end
