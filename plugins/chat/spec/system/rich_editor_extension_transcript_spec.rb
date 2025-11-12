# frozen_string_literal: true

describe "chat transcripts in rich editor", type: :system do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end
  fab!(:channel, :chat_channel)
  fab!(:message_1) do
    Fabricate(:chat_message, user: current_user, chat_channel: channel, created_at: 2.days.ago)
  end
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, created_at: 1.day.ago) }

  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before do
    SiteSetting.chat_enabled = true
    sign_in(current_user)
  end

  it "works for single messages" do
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus

    markdown =
      Chat::TranscriptService.new(
        channel,
        current_user,
        messages_or_ids: [message_1],
      ).generate_markdown

    cdp.copy_paste(
      markdown,
      css_selector: PageObjects::Components::Composer.new.composer_input_selector,
    )

    expect(rich).to have_css(".chat-transcript", text: channel.name)
    expect(rich).to have_css(
      ".chat-transcript .chat-transcript-user .chat-transcript-username",
      text: message_1.user.username,
    )
    expect(rich).to have_css(".chat-transcript .chat-transcript-messages", text: message_1.message)
  end

  it "works for multiple messages" do
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus

    markdown =
      Chat::TranscriptService.new(
        channel,
        current_user,
        messages_or_ids: [message_1, message_2],
      ).generate_markdown

    cdp.copy_paste(
      markdown,
      css_selector: PageObjects::Components::Composer.new.composer_input_selector,
    )

    expect(rich).to have_css(".chat-transcript.chat-transcript-chained", count: 2)
    expect(rich).to have_css(
      ".chat-transcript .chat-transcript-meta",
      text: "Originally sent in #{channel.name}",
    )
    expect(rich).to have_css(
      ".chat-transcript:nth-of-type(1) .chat-transcript-user .chat-transcript-username",
      text: message_1.user.username,
    )
    expect(rich).to have_css(
      ".chat-transcript:nth-of-type(2) .chat-transcript-user .chat-transcript-username",
      text: message_2.user.username,
    )
    expect(rich).to have_css(
      ".chat-transcript:nth-of-type(1) .chat-transcript-messages",
      text: message_1.message,
    )
    expect(rich).to have_css(
      ".chat-transcript:nth-of-type(2) .chat-transcript-messages",
      text: message_2.message,
    )
  end

  describe "sanitizing" do
    before { SiteSetting.content_security_policy = false }

    it "sanitizes thread title" do
      channel.update!(threading_enabled: true)
      thread =
        Fabricate(
          :chat_thread,
          title: "Thread <video src=_ onloadstart=confirm(document.domain)>",
          channel: channel,
          with_replies: 2,
        )

      page.visit "/new-topic"
      expect(composer).to be_opened
      composer.focus

      markdown =
        Chat::TranscriptService.new(
          channel,
          current_user,
          messages_or_ids: thread.replies.to_a.map(&:id),
        ).generate_markdown

      expect_no_alert do
        cdp.copy_paste(
          markdown,
          css_selector: PageObjects::Components::Composer.new.composer_input_selector,
        )

        expect(rich).to have_css(".chat-transcript")
      end
    end

    it "sanitizes channel title" do
      channel.update!(
        name: "Channel <video src=_ onloadstart=confirm(document.domain)>",
        threading_enabled: true,
      )

      page.visit "/new-topic"
      expect(composer).to be_opened
      composer.focus

      markdown =
        Chat::TranscriptService.new(
          channel,
          current_user,
          messages_or_ids: [message_1.id],
        ).generate_markdown

      expect_no_alert do
        cdp.copy_paste(
          markdown,
          css_selector: PageObjects::Components::Composer.new.composer_input_selector,
        )

        expect(rich).to have_css(".chat-transcript")
      end
    end
  end
end
