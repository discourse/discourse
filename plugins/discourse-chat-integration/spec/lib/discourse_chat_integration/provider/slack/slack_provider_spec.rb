# frozen_string_literal: true

RSpec.describe DiscourseChatIntegration::Provider::SlackProvider do
  let(:post) { Fabricate(:post) }

  describe ".excerpt" do
    describe "when post contains emoijs" do
      before { post.update!(raw: ":slight_smile: This is a test") }

      it "should return the right excerpt" do
        expect(described_class.excerpt(post)).to eq("🙂 This is a test")
      end
    end

    describe "when post contains onebox" do
      it "should return the right excerpt" do
        post.update!(cooked: <<~COOKED)
        <aside class=\"onebox whitelistedgeneric\">
          <header class=\"source\">
            <a href=\"http://somesource.com\">
              meta.discourse.org
            </a>
          </header>

          <article class=\"onebox-body\">
            <img src=\"http://somesource.com\" width=\"\" height=\"\" class=\"thumbnail\">

            <h3>
              <a href=\"http://somesource.com\">
                Some text
              </a>
            </h3>

            <p>
              some text
            </p>

          </article>

          <div class=\"onebox-metadata\">\n    \n    \n</div>
          <div style=\"clear: both\"></div>
        </aside>
        COOKED

        expect(described_class.excerpt(post)).to eq("<http://somesource.com|meta.discourse.org>")
      end
    end

    describe "when post contains an email" do
      it "should return the right excerpt" do
        post.update!(cooked: <<~COOKED)
            The address is <a href=\"mailto:someone@domain.com\">my email</a>
        COOKED

        expect(described_class.excerpt(post)).to eq(
          "The address is <mailto:someone@domain.com|my email>",
        )
      end
    end
  end

  describe ".valid_slack_incoming_webhook_url?" do
    it "returns true for an incoming webhook URL under /services/" do
      expect(
        described_class.valid_slack_incoming_webhook_url?(
          "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX",
        ),
      ).to eq(true)
    end

    it "returns true for a workflow webhook URL under /workflows/" do
      expect(
        described_class.valid_slack_incoming_webhook_url?(
          "https://hooks.slack.com/workflows/0000000000000/0000000000000/XXXXXXXXXXXXXXXXXXXXXXXX",
        ),
      ).to eq(true)
    end

    it "returns false for http" do
      expect(
        described_class.valid_slack_incoming_webhook_url?(
          "http://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX",
        ),
      ).to eq(false)
    end

    it "returns false when the host is not hooks.slack.com" do
      expect(
        described_class.valid_slack_incoming_webhook_url?(
          "https://evil.example.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX",
        ),
      ).to eq(false)
    end

    it "returns false when the path is not /services/ or /workflows/" do
      expect(
        described_class.valid_slack_incoming_webhook_url?("https://hooks.slack.com/other/path"),
      ).to eq(false)
    end

    it "returns false for an invalid URL" do
      expect(described_class.valid_slack_incoming_webhook_url?("not a url")).to eq(false)
    end
  end

  describe ".trigger_notifications" do
    before do
      SiteSetting.chat_integration_slack_outbound_webhook_url =
        "https://hooks.slack.com/services/abcde"
      SiteSetting.chat_integration_slack_enabled = true
    end

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(provider: "slack", data: { identifier: "#general" })
    end

    it "sends a webhook request" do
      stub1 =
        stub_request(:post, SiteSetting.chat_integration_slack_outbound_webhook_url).to_return(
          body: "success",
        )
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, SiteSetting.chat_integration_slack_outbound_webhook_url).to_return(
          status: 400,
          body: "error",
        )
      expect(stub1).to have_been_requested.times(0)
      expect { described_class.trigger_notification(post, chan1, nil) }.to raise_exception(
        DiscourseChatIntegration::ProviderError,
      )
      expect(stub1).to have_been_requested.once
    end

    describe "with api token" do
      before do
        SiteSetting.chat_integration_slack_access_token = "magic"
        @ts = "#{Time.now.to_i}.012345"
        @ts2 = "#{Time.now.to_i}.012346"
        @ts3 = "#{Time.now.to_i}.0123467"
        @stub1 =
          stub_request(:post, SiteSetting.chat_integration_slack_outbound_webhook_url).to_return(
            body: "success",
          )
        @stub2 =
          stub_request(:post, %r{https://slack.com/api/chat.postMessage}).to_return(
            body:
              "{\"ok\":true, \"ts\": \"#{@ts}\", \"message\": {\"attachments\": [], \"username\":\"blah\", \"text\":\"blah2\"} }",
            headers: {
              "Content-Type" => "application/json",
            },
          )
        @thread_stub =
          stub_request(:post, %r{https://slack.com/api/chat.postMessage}).with(
            body: hash_including("thread_ts" => @ts),
          ).to_return(
            body:
              "{\"ok\":true, \"ts\": \"#{@ts}\", \"message\": {\"attachments\": [], \"username\":\"blah\", \"text\":\"blah2\", \"thread_ts\":\"#{@ts}\"} }",
            headers: {
              "Content-Type" => "application/json",
            },
          )
        @thread_stub2 =
          stub_request(:post, %r{https://slack.com/api/chat.postMessage}).with(
            body: hash_including("thread_ts" => @ts),
          ).to_return(
            body:
              "{\"ok\":true, \"ts\": \"#{@ts3}\", \"message\": {\"attachments\": [], \"username\":\"blah\", \"text\":\"blah2\", \"thread_ts\":\"#{@ts}\"} }",
            headers: {
              "Content-Type" => "application/json",
            },
          )
      end

      it "sends an api request" do
        expect(@stub2).to have_been_requested.times(0)
        expect(@thread_stub).to have_been_requested.times(0)

        described_class.trigger_notification(post, chan1, nil)
        expect(@stub1).to have_been_requested.times(0)
        expect(@stub2).to have_been_requested.once
        expect(described_class.get_slack_thread_ts(post.topic, chan1.data["identifier"])).to eq(@ts)
        expect(@thread_stub).to have_been_requested.times(0)
      end

      it "sends thread id for thread" do
        expect(@thread_stub).to have_been_requested.times(0)

        rule = DiscourseChatIntegration::Rule.create(channel: chan1, filter: "thread")
        described_class.set_slack_thread_ts(post.topic, chan1.data["identifier"], @ts)

        described_class.trigger_notification(post, chan1, rule)
        expect(@thread_stub).to have_been_requested.once
      end

      it "tracks threading in different channels separately" do
        expect(@thread_stub).to have_been_requested.times(0)
        chan2 =
          DiscourseChatIntegration::Channel.create(
            provider: "dummy2",
            data: {
              "identifier" => "#random",
            },
          )

        rule = DiscourseChatIntegration::Rule.create(channel: chan1, filter: "thread")
        rule2 = DiscourseChatIntegration::Rule.create(channel: chan2, filter: "thread")
        described_class.set_slack_thread_ts(post.topic, chan1.data["identifier"], @ts)
        described_class.set_slack_thread_ts(post.topic, chan2.data["identifier"], @ts2)

        described_class.trigger_notification(post, chan1, rule)
        described_class.trigger_notification(post, chan2, rule2)
        expect(@thread_stub).to have_been_requested.once
        expect(@thread_stub2).to have_been_requested.once

        post.topic.reload
        expect(described_class.get_slack_thread_ts(post.topic, "#general")).to eq(@ts)
        expect(described_class.get_slack_thread_ts(post.topic, "#random")).to eq(@ts)
      end

      it "recognizes slack thread ts in comment" do
        post.update!(cooked: "cooked", raw: <<~RAW)
             My fingers are typing words that improve `raw_quality`
             <!--SLACK_CHANNEL_ID=#general;SLACK_TS=#{@ts}-->
        RAW

        rule = DiscourseChatIntegration::Rule.create(channel: chan1, filter: "thread")

        described_class.trigger_notification(post, chan1, rule)
        expect(described_class.get_slack_thread_ts(post.topic, chan1.data["identifier"])).to eq(@ts)

        expect(@thread_stub).to have_been_requested.times(1)
      end

      it "handles errors correctly" do
        @stub2 =
          stub_request(:post, %r{https://slack.com/api/chat.postMessage}).to_return(
            body: "{\"ok\":false }",
            headers: {
              "Content-Type" => "application/json",
            },
          )
        expect { described_class.trigger_notification(post, chan1, nil) }.to raise_exception(
          DiscourseChatIntegration::ProviderError,
        )
        expect(@stub2).to have_been_requested.once
      end
    end
  end

  describe ".create_slack_message" do
    it "should work with a simple message" do
      content = "Simple message"
      url = "http://example.com"
      message = { channel: "#general", username: "Discourse", content: "#{content} - #{url}" }
      result =
        described_class.create_slack_message(
          context: {
          },
          content: content,
          channel_name: "general",
          url: url,
        )
      expect(
        {
          channel: result[:channel],
          username: result[:username],
          content: result[:attachments][0][:text],
        },
      ).to eq(message)
    end

    it "should do the replacements" do
      topic = Fabricate(:topic)
      topic.posts << Fabricate(:post, topic: topic)
      tag1, tag2, tag3, tag4 = [Fabricate(:tag), Fabricate(:tag), Fabricate(:tag), Fabricate(:tag)]
      content =
        "The topic title is: ${TOPIC}
         removed tags: ${REMOVED_TAGS}
         added tags: ${ADDED_TAGS}"

      result =
        described_class.create_slack_message(
          context: {
            "topic" => topic,
            "removed_tags" => [tag1.name, tag2.name],
            "added_tags" => [tag3.name, tag4.name],
            "kind" => DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED,
          },
          content: content,
          channel_name: "general",
          url: "http://example.com",
        )
      text = result[:attachments][0][:text]
      expect(text).to include(topic.title)
      expect(text).to include("<#{tag1.full_url}|#{tag1.name}>, <#{tag2.full_url}|#{tag2.name}>")
      expect(text).to include("<#{tag3.full_url}|#{tag3.name}>, <#{tag4.full_url}|#{tag4.name}>")
    end

    it "should do the replacements for ${ADDED_AND_REMOVED}" do
      topic = Fabricate(:topic)
      topic.posts << Fabricate(:post, topic: topic)
      tag1, tag2 = [Fabricate(:tag), Fabricate(:tag)]
      content = "${ADDED_AND_REMOVED}"
      result =
        described_class.create_slack_message(
          context: {
            "topic" => topic,
            "added_tags" => [tag2.name],
            "removed_tags" => [tag1.name],
            "kind" => DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED,
          },
          content: content,
          channel_name: "general",
          url: "http://example.com",
        )
      text = result[:attachments][0][:text]
      expect(text).to include(
        I18n.t(
          "chat_integration.provider.slack.messaging.topic_tag_changed.added_and_removed",
          added: "<#{tag2.full_url}|#{tag2.name}>",
          removed: "<#{tag1.full_url}|#{tag1.name}>",
        ),
      )

      result =
        described_class.create_slack_message(
          context: {
            "topic" => topic,
            "added_tags" => [],
            "removed_tags" => [tag1.name],
            "kind" => DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED,
          },
          content: content,
          channel_name: "general",
          url: "http://example.com",
        )
      text = result[:attachments][0][:text]
      expect(text).to include(
        I18n.t(
          "chat_integration.provider.slack.messaging.topic_tag_changed.removed",
          removed: "<#{tag1.full_url}|#{tag1.name}>",
        ),
      )

      result =
        described_class.create_slack_message(
          context: {
            "topic" => topic,
            "added_tags" => [tag2.name],
            "removed_tags" => [],
            "kind" => DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED,
          },
          content: content,
          channel_name: "general",
          url: "http://example.com",
        )
      text = result[:attachments][0][:text]
      expect(text).to include(
        I18n.t(
          "chat_integration.provider.slack.messaging.topic_tag_changed.added",
          added: "<#{tag2.full_url}|#{tag2.name}>",
        ),
      )
    end

    it "should raise errors if tags are not present but uses in content" do
      topic = Fabricate(:topic)
      topic.posts << Fabricate(:post, topic: topic)
      content = "This should not work ${ADDED_TAGS}"

      expect {
        described_class.create_slack_message(
          context: {
            "topic" => topic,
            "kind" => DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED,
            "added_tags" => [],
            "removed_tags" => [],
          },
          content: content,
          channel_name: "general",
          url: "http://example.com",
        )
      }.to raise_error(StandardError)
    end
  end

  describe ".get_channel_by_name" do
    it "returns the right channel" do
      expected =
        DiscourseChatIntegration::Channel.create!(
          provider: "slack",
          data: {
            identifier: "#general",
          },
        )
      expect(described_class.get_channel_by_name("#general")).to eq(expected)
    end
  end

  describe ".setup" do
    fab!(:admin)

    before do
      SiteSetting.chat_integration_slack_enabled = false
      SiteSetting.chat_integration_slack_access_token = ""
      SiteSetting.chat_integration_slack_outbound_webhook_url = ""
    end

    it "raises when both token and webhook URL are blank" do
      expect { described_class.setup(admin, {}) }.to raise_error(
        DiscourseChatIntegration::ProviderError,
      ) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.slack.errors.at_least_one_required",
        )
      end
    end

    it "calls auth.test and persists token when token is provided" do
      stub =
        stub_request(:post, "https://slack.com/api/auth.test").to_return(
          body: { ok: true }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      described_class.setup(admin, { chat_integration_slack_access_token: "xoxb-test-token" })

      expect(stub).to have_been_requested.once
      expect(SiteSetting.chat_integration_slack_access_token).to eq("xoxb-test-token")
      expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
    end

    it "raises when auth.test returns ok false" do
      stub_request(:post, "https://slack.com/api/auth.test").to_return(
        body: { ok: false, error: "invalid_auth" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.setup(admin, { chat_integration_slack_access_token: "bad" })
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq("chat_integration.provider.slack.errors.auth_error")
      end
    end

    it "persists webhook URL and enables provider when only webhook is provided" do
      url = "https://hooks.slack.com/services/T00000000/B00000000/xxxxxxxxxxxxxxxxxxxxxxxx"

      described_class.setup(admin, { chat_integration_slack_outbound_webhook_url: url })

      expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(url)
      expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
    end

    it "raises when webhook URL is not a valid Slack incoming webhook URL" do
      expect {
        described_class.setup(
          admin,
          { chat_integration_slack_outbound_webhook_url: "https://example.com/hook" },
        )
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.slack.errors.invalid_webhook_url",
        )
      end
    end

    it "raises when webhook URL uses HTTP instead of HTTPS" do
      expect {
        described_class.setup(
          admin,
          {
            chat_integration_slack_outbound_webhook_url:
              "http://hooks.slack.com/services/T00000000/B00000000/xxx",
          },
        )
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.slack.errors.invalid_webhook_url",
        )
      end
    end

    it "raises when webhook URL has wrong path prefix" do
      expect {
        described_class.setup(
          admin,
          { chat_integration_slack_outbound_webhook_url: "https://hooks.slack.com/other/path" },
        )
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.slack.errors.invalid_webhook_url",
        )
      end
    end

    it "accepts a valid /workflows/ webhook URL" do
      url = "https://hooks.slack.com/workflows/T00000000/B00000000/xxxxxxxxxxxxxxxxxxxxxxxx"

      described_class.setup(admin, { chat_integration_slack_outbound_webhook_url: url })

      expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(url)
      expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
    end

    it "persists both token and webhook when both are provided" do
      stub_request(:post, "https://slack.com/api/auth.test").to_return(
        body: { ok: true }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      hook = "https://hooks.slack.com/services/T00000000/B00000000/xxxxxxxxxxxxxxxxxxxxxxxx"

      described_class.setup(
        admin,
        {
          chat_integration_slack_access_token: "xoxb-both",
          chat_integration_slack_outbound_webhook_url: hook,
        },
      )

      expect(SiteSetting.chat_integration_slack_access_token).to eq("xoxb-both")
      expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(hook)
    end

    it "raises when webhook URL is invalid even if the token is valid" do
      stub_request(:post, "https://slack.com/api/auth.test").to_return(
        body: { ok: true }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.setup(
          admin,
          {
            chat_integration_slack_access_token: "xoxb-good",
            chat_integration_slack_outbound_webhook_url: "https://example.com/hook",
          },
        )
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.slack.errors.invalid_webhook_url",
        )
      end
    end
  end
end
