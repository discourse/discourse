# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::SlackProvider::SlackTranscript do
  before { Discourse.cache.clear }

  let(:messages_fixture) do
    [
      {
        type: "message",
        user: "U6JSSESES",
        text: "Yeah, should make posting slack transcripts much easier",
        ts: "1501801665.062694",
      },
      {
        type: "message",
        user: "U5Z773QLZ",
        text: "Oooh a new discourse plugin <@U5Z773QLS> ???",
        ts: "1501801643.056375",
      },
      { type: "message", user: "U6E2W7R8C", text: "Which one?", ts: "1501801635.053761" },
      {
        type: "message",
        user: "U6JSSESES",
        text: "So, who's interested in the new <https://meta.discourse.org|discourse plugin>?",
        ts: "1501801629.052212",
      },
      {
        type: "message",
        user: "U820GH3LA",
        text: "I'm interested!!",
        ts: "1501801634.053761",
        thread_ts: "1501801629.052212",
      },
      {
        text: "Check this out!",
        username: "Test Community",
        bot_id: "B6C6JNUDN",
        attachments: [
          {
            author_name: "@david",
            fallback: "Discourse can now be integrated with Mattermost! - @david",
            text: "Hey <http://localhost/groups/team|@team>, what do you think about this?",
            title: "Discourse can now be integrated with Mattermost! [Announcements] ",
            id: 1,
            title_link:
              "http://localhost:3000/t/discourse-can-now-be-integrated-with-mattermost/51/4",
            color: "283890",
            mrkdwn_in: ["text"],
          },
        ],
        type: "message",
        subtype: "bot_message",
        ts: "1501615820.949638",
      },
      {
        type: "message",
        user: "U5Z773QLS",
        text: "Let’s try some *bold text* <@U5Z773QLZ> <@someotheruser>",
        ts: "1501093331.439776",
      },
    ]
  end

  let(:users_fixture) do
    [
      {
        id: "U6JSSESES",
        name: "threader",
        profile: {
          image_24: "https://example.com/avatar",
          display_name: "Threader",
          real_name: "A. Threader",
        },
      },
      {
        id: "U820GH3LA",
        name: "responder",
        profile: {
          image_24: "https://example.com/avatar",
          display_name: "Responder",
          real_name: "A. Responder",
        },
      },
      {
        id: "U5Z773QLS",
        name: "awesomeguyemail",
        profile: {
          image_24: "https://example.com/avatar",
          display_name: "awesomeguy",
          real_name: "actually just a guy",
        },
      },
      {
        id: "U5Z773QLZ",
        name: "otherguyemail",
        profile: {
          image_24: "https://example.com/avatar",
          display_name: "",
          real_name: "another guy",
        },
      },
    ]
  end

  let(:transcript) { described_class.new(channel_name: "#general", channel_id: "G1234") }
  before { SiteSetting.chat_integration_slack_access_token = "abcde" }

  it "doesn't raise an error when there are no messages to guess" do
    transcript.instance_variable_set(:@messages, [])
    expect(transcript.guess_first_message(skip_messages: 1)).to eq(false)
  end

  describe "loading users" do
    it "loads users correctly" do
      stub_request(:post, "https://slack.com/api/users.list").with(
        body: {
          token: "abcde",
          cursor: nil,
          limit: "200",
        },
      ).to_return(
        status: 200,
        body: { ok: true, members: users_fixture, response_metadata: { next_cursor: "" } }.to_json,
      )

      expect(transcript.load_user_data).to be_truthy
    end

    it "handles failed connection" do
      stub_request(:post, "https://slack.com/api/users.list").to_return(status: 500, body: "")

      expect(transcript.load_user_data).to eq(false)
    end

    it "handles slack failure" do
      stub_request(:post, "https://slack.com/api/users.list").to_return(
        status: 200,
        body: { ok: false }.to_json,
      )

      expect(transcript.load_user_data).to eq(false)
    end
  end

  context "with loaded users" do
    before do
      stub_request(:post, "https://slack.com/api/users.list").to_return(
        status: 200,
        body: { ok: true, members: users_fixture, response_metadata: { next_cursor: "" } }.to_json,
      )
      transcript.load_user_data
    end

    describe "loading history" do
      it "loads messages correctly" do
        stub_request(:post, "https://slack.com/api/conversations.history").with(
          body: hash_including(token: "abcde", channel: "G1234"),
        ).to_return(status: 200, body: { ok: true, messages: messages_fixture }.to_json)

        expect(transcript.load_chat_history).to be_truthy
      end

      it "handles failed connection" do
        stub_request(:post, "https://slack.com/api/conversations.history").to_return(
          status: 500,
          body: {}.to_json,
        )

        expect(transcript.load_chat_history).to be_falsey
      end

      it "handles slack failure" do
        stub_request(:post, "https://slack.com/api/conversations.history").to_return(
          status: 200,
          body: { ok: false }.to_json,
        )

        expect(transcript.load_chat_history).to be_falsey
      end
    end

    context "with thread_ts specified" do
      let(:thread_transcript) do
        described_class.new(
          channel_name: "#general",
          channel_id: "G1234",
          requested_thread_ts: "1501801629.052212",
        )
      end

      before do
        thread_transcript.load_user_data
        stub_request(:post, "https://slack.com/api/conversations.replies").with(
          body: hash_including(token: "abcde", channel: "G1234", ts: "1501801629.052212"),
        ).to_return(status: 200, body: { ok: true, messages: messages_fixture[3..4] }.to_json)
        thread_transcript.load_chat_history
      end

      it "includes messages in a thread" do
        expect(thread_transcript.messages.length).to eq(2)
      end

      it "loads in chronological order" do # replies API presents messages in actual chronological order
        expect(thread_transcript.messages.first.ts).to eq("1501801629.052212")
      end

      it "includes slack thread identifiers in body" do
        text = thread_transcript.build_transcript
        expect(text).to include("<!--SLACK_CHANNEL_ID=#general;SLACK_TS=1501801629.052212-->")
      end
    end

    context "with loaded messages" do
      before do
        stub_request(:post, "https://slack.com/api/conversations.history").with(
          body: hash_including(token: "abcde", channel: "G1234"),
        ).to_return(status: 200, body: { ok: true, messages: messages_fixture }.to_json)
        transcript.load_chat_history
      end

      it "ignores messages in a thread" do
        expect(transcript.messages.length).to eq(6)
      end

      it "loads in chronological order" do # API presents in reverse chronological
        expect(transcript.messages.first.ts).to eq("1501093331.439776")
      end

      it "handles bold text" do
        expect(transcript.messages.first.text).to start_with("Let’s try some **bold text** ")
      end

      it "handles links" do
        expect(transcript.messages[2].text).to eq(
          "So, who's interested in the new [discourse plugin](https://meta.discourse.org)?",
        )
      end

      it "includes attachments" do
        expect(transcript.messages[1].attachments.first).to eq(
          "Discourse can now be integrated with Mattermost! - @david",
        )
      end

      it "can generate URL" do
        expect(transcript.messages.first.url).to eq(
          "https://slack.com/archives/G1234/p1501093331439776",
        )
      end

      it "includes attachments in raw text" do
        transcript.set_first_message_by_ts("1501615820.949638")
        expect(transcript.first_message.raw_text).to eq(
          "Check this out!\n - Discourse can now be integrated with Mattermost! - @david\n",
        )
      end

      it "gives correct first and last messages" do
        expect(transcript.first_message_number).to eq(0)
        expect(transcript.last_message_number).to eq(transcript.messages.length - 1)

        expect(transcript.first_message.ts).to eq("1501093331.439776")
        expect(transcript.last_message.ts).to eq("1501801665.062694")
      end

      it "can change first and last messages by index" do
        expect(transcript.set_first_message_by_index(999)).to be_falsey
        expect(transcript.set_first_message_by_index(1)).to be_truthy

        expect(transcript.set_last_message_by_index(-2)).to be_truthy

        expect(transcript.first_message.ts).to eq("1501615820.949638")
        expect(transcript.last_message.ts).to eq("1501801643.056375")
      end

      it "can change first and last messages by ts" do
        expect(transcript.set_first_message_by_ts("blah")).to be_falsey
        expect(transcript.set_first_message_by_ts("1501615820.949638")).to be_truthy

        expect(transcript.set_last_message_by_ts("1501801629.052212")).to be_truthy

        expect(transcript.first_message_number).to eq(1)
        expect(transcript.last_message_number).to eq(2)
      end

      it "can guess the first message" do
        expect(transcript.guess_first_message(skip_messages: 1)).to eq(true)
        expect(transcript.first_message.ts).to eq("1501801629.052212")
      end

      it "handles usernames correctly" do
        expect(transcript.first_message.username).to eq("awesomeguy") # Normal user
        expect(transcript.messages[1].username).to eq("Test_Community") # Bot user
        expect(transcript.messages[3].username).to eq(nil) # Unknown normal user
        # Normal user, display_name not set (fall back to real_name)
        expect(transcript.messages[4].username).to eq("another_guy")
      end

      it "handles user mentions correctly" do
        # User with display_name not set, unrecognized user
        expect(transcript.first_message.text).to eq(
          "Let’s try some **bold text** @another_guy @someotheruser",
        )
        # Normal user
        expect(transcript.messages[4].text).to eq("Oooh a new discourse plugin @awesomeguy ???")
      end

      it "handles avatars correctly" do
        expect(transcript.first_message.avatar).to eq("https://example.com/avatar") # Normal user
        expect(transcript.messages[1].avatar).to eq(nil) # Bot user
      end

      it "creates a transcript correctly" do
        transcript.set_last_message_by_index(1)

        text = transcript.build_transcript

        expected = <<~END
        [quote]
        [**View in #general on Slack**](https://slack.com/archives/G1234/p1501093331439776)

        ![awesomeguy] **@awesomeguy:** Let’s try some **bold text** @another_guy @someotheruser

        **@Test_Community:** Check this out!
        > Discourse can now be integrated with Mattermost! - @david

        [/quote]

        [awesomeguy]: https://example.com/avatar
        END

        expect(text).to eq(expected)
      end

      it "omits quote tags when disabled" do
        transcript.set_last_message_by_index(1)

        text = transcript.build_transcript
        expect(text).to include("[quote]")
        expect(text).to include("[/quote]")

        SiteSetting.chat_integration_slack_transcript_quote = false

        text = transcript.build_transcript
        expect(text).not_to include("[quote]")
        expect(text).not_to include("[/quote]")
      end

      it "creates the slack UI correctly" do
        transcript.set_last_message_by_index(1)
        ui = transcript.build_slack_ui

        first_ui = ui[:attachments][0]
        last_ui = ui[:attachments][1]

        # The callback IDs are used to keep track of what the other option is
        expect(first_ui[:callback_id]).to eq(transcript.last_message.ts)
        expect(last_ui[:callback_id]).to eq(transcript.first_message.ts)

        # The timestamps should match up to the actual messages
        expect(first_ui[:ts]).to eq(transcript.first_message.ts)
        expect(last_ui[:ts]).to eq(transcript.last_message.ts)

        # Raw text should be used
        expect(first_ui[:text]).to eq(transcript.first_message.raw_text)
      end
    end

    describe "message formatting" do
      it "handles code block newlines" do
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" => "Here is some code```my code\nwith newline```",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq(<<~MD)
          Here is some code
          ```
          my code
          with newline
          ```
        MD
      end

      it "handles multiple code blocks" do
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" =>
                "Here is some code```my code\nwith newline```and another```some more code```",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq(<<~MD)
          Here is some code
          ```
          my code
          with newline
          ```
          and another
          ```
          some more code
          ```
        MD
      end

      it "handles strikethrough" do
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" => "Some ~strikethrough~",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq("Some ~~strikethrough~~")
      end

      it "handles slack links" do
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" =>
                "A link to <https://google.com|google>, <https://autolinked.com|https://autolinked.com>, <https://notext.com>, <#channel>, <@user>",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq(
          "A link to [google](https://google.com), <https://autolinked.com>, <https://notext.com>, #channel, @user",
        )
      end

      it "does not format things inside backticks" do
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" =>
                "You can strikethrough like `~this~`, bold like `*this*` and link like `[https://example.com](https://example.com)`",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq(
          "You can strikethrough like `~this~`, bold like `*this*` and link like `[https://example.com](https://example.com)`",
        )
      end

      it "unescapes html in backticks" do
        # Because Slack escapes HTML entities, even in backticks
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" => "The code is `&lt;stuff&gt;`",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq("The code is `<stuff>`")
      end

      it "updates emoji dashes to underscores" do
        # Discourse does not allow dashes in emoji names, so this helps communities have matching custom emojis
        message =
          DiscourseChatIntegration::Provider::SlackProvider::SlackMessage.new(
            {
              "type" => "message",
              "user" => "U5Z773QLS",
              "text" => "This is :my-emoji:",
              "ts" => "1501093331.439776",
            },
            transcript,
          )
        expect(message.text).to eq("This is :my_emoji:")
      end
    end
  end
end
