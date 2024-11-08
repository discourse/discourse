# frozen_string_literal: true

describe Chat::Message do
  fab!(:message) { Fabricate(:chat_message, message: "hey friend, what's up?!") }

  it { is_expected.to have_many(:chat_mentions).dependent(:destroy) }

  it "supports custom fields" do
    message.custom_fields["test"] = "test"
    message.save_custom_fields
    loaded_message = Chat::Message.find(message.id)
    expect(loaded_message.custom_fields["test"]).to eq("test")
    expect(Chat::MessageCustomField.first.message.id).to eq(message.id)
  end

  describe "validations" do
    subject(:message) { described_class.new(message: "") }

    it { is_expected.to validate_length_of(:cooked).is_at_most(20_000) }
  end

  describe ".in_thread?" do
    context "when in a thread enabled channel" do
      fab!(:message) do
        Fabricate(
          :chat_message,
          thread_id: 1,
          chat_channel: Fabricate(:chat_channel, threading_enabled: true),
        )
      end

      it "returns true for messages in a thread" do
        expect(message.in_thread?).to eq(true)
      end

      it "returns false for messages not in a thread" do
        message.update!(thread_id: nil)
        expect(message.in_thread?).to eq(false)
      end
    end

    context "when the thread is forced" do
      fab!(:message) { Fabricate(:chat_message, thread: Fabricate(:chat_thread, force: true)) }

      it "returns true for messages in a thread" do
        expect(message.in_thread?).to eq(true)
      end

      it "returns false for messages not in a thread" do
        message.update!(thread_id: nil)
        expect(message.in_thread?).to eq(false)
      end
    end
  end

  describe ".cook" do
    it "does not support HTML tags" do
      cooked = described_class.cook("<h1>test</h1>")

      expect(cooked).to eq("<p>&lt;h1&gt;test&lt;/h1&gt;</p>")
    end

    it "correctly extracts mentions with dots" do
      user = Fabricate(:user)
      cooked = described_class.cook("@#{user.username}...test")

      expect(cooked).to eq(
        "<p><a class=\"mention\" href=\"/u/#{user.username}\">@#{user.username}</a>…test</p>",
      )
    end

    it "supports kbd" do
      cooked = described_class.cook <<~MD
      <kbd>Esc</kbd> is pressed
      MD

      expect(cooked).to match_html <<~HTML
      <p><kbd>Esc</kbd> is pressed</p>
      HTML
    end

    context "when message is made by a bot user" do
      it "supports headings" do
        cooked = described_class.cook(<<~MD, user_id: -1)
        # h1
        ## h2
        ### h3
        #### h4
        ##### h5
        ###### h6
        MD

        expect(cooked).to match_html <<~HTML
        <h1><a name="h1-1" class="anchor" href="#h1-1"></a>h1</h1>
        <h2><a name="h2-2" class="anchor" href="#h2-2"></a>h2</h2>
        <h3><a name="h3-3" class="anchor" href="#h3-3"></a>h3</h3>
        <h4><a name="h4-4" class="anchor" href="#h4-4"></a>h4</h4>
        <h5><a name="h5-5" class="anchor" href="#h5-5"></a>h5</h5>
        <h6><a name="h6-6" class="anchor" href="#h6-6"></a>h6</h6>
        HTML
      end
    end

    it "doesn't support headings" do
      cooked = described_class.cook("# test")

      expect(cooked).to match_html <<~HTML
      <p># test</p>
      HTML
    end

    it "supports horizontal replacement" do
      cooked = described_class.cook("---")

      expect(cooked).to eq("<p>—</p>")
    end

    it "supports backticks rule" do
      cooked = described_class.cook("`test`")

      expect(cooked).to eq("<p><code>test</code></p>")
    end

    it "supports fence rule" do
      cooked = described_class.cook(<<~RAW)
      ```
      something = test
      ```
      RAW

      expect(cooked).to eq(<<~COOKED.chomp)
      <pre><code class="lang-auto">something = test
      </code></pre>
      COOKED
    end

    it "supports fence rule with language support" do
      cooked = described_class.cook(<<~RAW)
      ```ruby
      Widget.triangulate(argument: "no u")
      ```
      RAW

      expect(cooked).to eq(<<~COOKED.chomp)
      <pre data-code-wrap="ruby"><code class="lang-ruby">Widget.triangulate(argument: "no u")
      </code></pre>
      COOKED
    end

    it "supports code rule" do
      cooked = described_class.cook("    something = test")

      expect(cooked).to eq("<pre><code>something = test\n</code></pre>")
    end

    it "supports blockquote rule" do
      cooked = described_class.cook("> a quote")

      expect(cooked).to eq("<blockquote>\n<p>a quote</p>\n</blockquote>")
    end

    it "supports quote bbcode" do
      topic = Fabricate(:topic, title: "Some quotable topic")
      post = Fabricate(:post, topic: topic)
      SiteSetting.external_system_avatars_enabled = false
      avatar_src =
        "//test.localhost#{User.system_avatar_template(post.user.username).gsub("{size}", "48")}"

      cooked = described_class.cook(<<~RAW)
      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]
      Mark me...this will go down in history.
      [/quote]
      RAW

      expect(cooked).to eq(<<~COOKED.chomp)
      <aside class="quote no-group" data-username="#{post.user.username}" data-post="#{post.post_number}" data-topic="#{topic.id}">
      <div class="title">
      <div class="quote-controls"></div>
      <img loading="lazy" alt="" width="24" height="24" src="#{avatar_src}" class="avatar"><a href="http://test.localhost/t/some-quotable-topic/#{topic.id}/#{post.post_number}">#{topic.title}</a></div>
      <blockquote>
      <p>Mark me…this will go down in history.</p>
      </blockquote>
      </aside>
      COOKED
    end

    it "supports chat quote bbcode" do
      chat_channel = Fabricate(:category_channel, name: "testchannel")
      user = Fabricate(:user, username: "chatbbcodeuser")
      user2 = Fabricate(:user, username: "otherbbcodeuser")
      avatar_src =
        "//test.localhost#{User.system_avatar_template(user.username).gsub("{size}", "48")}"
      avatar_src2 =
        "//test.localhost#{User.system_avatar_template(user2.username).gsub("{size}", "48")}"
      msg1 =
        Fabricate(
          :chat_message,
          chat_channel: chat_channel,
          message: "this is the first message",
          user: user,
        )
      msg2 =
        Fabricate(
          :chat_message,
          chat_channel: chat_channel,
          message: "and another cool one",
          user: user2,
        )
      other_messages_to_quote = [msg1, msg2]
      cooked =
        described_class.cook(
          Chat::TranscriptService.new(
            chat_channel,
            Fabricate(:user),
            messages_or_ids: other_messages_to_quote.map(&:id),
          ).generate_markdown,
        )

      expect(cooked).to eq(<<~COOKED.chomp)
        <div class="chat-transcript chat-transcript-chained" data-message-id="#{msg1.id}" data-username="chatbbcodeuser" data-datetime="#{msg1.created_at.iso8601}" data-channel-name="testchannel" data-channel-id="#{chat_channel.id}">
        <div class="chat-transcript-meta">
        Originally sent in <a href="/chat/c/-/#{chat_channel.id}">testchannel</a></div>
        <div class="chat-transcript-user">
        <div class="chat-transcript-user-avatar">
        <img loading="lazy" alt="" width="24" height="24" src="#{avatar_src}" class="avatar"></div>
        <div class="chat-transcript-username">
        chatbbcodeuser</div>
        <div class="chat-transcript-datetime">
        <a href="/chat/c/-/#{chat_channel.id}/#{msg1.id}" title="#{msg1.created_at.iso8601}"></a></div>
        </div>
        <div class="chat-transcript-messages">
        <p>this is the first message</p></div>
        </div>
        <div class="chat-transcript chat-transcript-chained" data-message-id="#{msg2.id}" data-username="otherbbcodeuser" data-datetime="#{msg2.created_at.iso8601}">
        <div class="chat-transcript-user">
        <div class="chat-transcript-user-avatar">
        <img loading="lazy" alt="" width="24" height="24" src="#{avatar_src2}" class="avatar"></div>
        <div class="chat-transcript-username">
        otherbbcodeuser</div>
        <div class="chat-transcript-datetime">
        <span title="#{msg2.created_at.iso8601}"></span></div>
        </div>
        <div class="chat-transcript-messages">
        <p>and another cool one</p></div>
        </div>
      COOKED
    end

    it "supports strikethrough rule" do
      cooked = described_class.cook("~~test~~")

      expect(cooked).to eq("<p><s>test</s></p>")
    end

    it "supports emphasis rule" do
      cooked = described_class.cook("**bold**")

      expect(cooked).to eq("<p><strong>bold</strong></p>")
    end

    it "supports link markdown rule" do
      chat_message = Fabricate(:chat_message, message: "[test link](https://www.example.com)")

      expect(chat_message.cooked).to eq(
        "<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">test link</a></p>",
      )
    end

    it "supports table markdown plugin" do
      cooked = described_class.cook(<<~RAW)
      | Command | Description |
      | --- | --- |
      | git status | List all new or modified files |
      RAW

      expected = <<~COOKED
      <div class="md-table">
      <table>
      <thead>
      <tr>
      <th>Command</th>
      <th>Description</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td>git status</td>
      <td>List all new or modified files</td>
      </tr>
      </tbody>
      </table>
      </div>
      COOKED

      expect(cooked).to eq(expected.chomp)
    end

    it "supports onebox markdown plugin" do
      cooked = described_class.cook("https://www.example.com")

      expect(cooked).to eq(
        "<p><a href=\"https://www.example.com\" class=\"onebox\" target=\"_blank\" rel=\"noopener nofollow ugc\">https://www.example.com</a></p>",
      )
    end

    it "supports emoji plugin" do
      cooked = described_class.cook(":grin:")

      expect(cooked).to eq(
        "<p><img src=\"/images/emoji/twitter/grin.png?v=12\" title=\":grin:\" class=\"emoji only-emoji\" alt=\":grin:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
      )
    end

    it "supports mentions plugin" do
      cooked = described_class.cook("@mention")

      expect(cooked).to eq("<p><span class=\"mention\">@mention</span></p>")
    end

    it "supports hashtag autocomplete" do
      SiteSetting.chat_enabled = true

      category = Fabricate(:category)
      user = Fabricate(:user)

      cooked = described_class.cook("##{category.slug}", user_id: user.id)

      expect(cooked).to have_tag(
        "a",
        with: {
          class: "hashtag-cooked",
          href: category.url,
          "data-type": "category",
          "data-slug": category.slug,
          "data-id": category.id,
        },
      ) do
        with_tag("span", with: { class: "hashtag-icon-placeholder" })
      end
    end

    it "supports censored plugin" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor])

      cooked = described_class.cook(watched_word.word)

      expect(cooked).to eq("<p>■■■■■</p>")
    end

    it "includes links in pretty text excerpt if the raw message is a single link and the PrettyText excerpt is blank" do
      message =
        Fabricate.build(
          :chat_message,
          message: "https://twitter.com/EffinBirds/status/1518743508378697729",
        )
      expect(message.build_excerpt).to eq(
        "https://twitter.com/EffinBirds/status/1518743508378697729",
      )
      message =
        Fabricate.build(
          :chat_message,
          message: "https://twitter.com/EffinBirds/status/1518743508378697729",
          cooked: <<~COOKED,
          <aside class=\"onebox twitterstatus\" data-onebox-src=\"https://twitter.com/EffinBirds/status/1518743508378697729\">\n  <header class=\"source\">\n\n      <a href=\"https://twitter.com/EffinBirds/status/1518743508378697729\" target=\"_blank\" rel=\"nofollow ugc noopener\">twitter.com</a>\n  </header>\n\n  <article class=\"onebox-body\">\n    \n<h4><a href=\"https://twitter.com/EffinBirds/status/1518743508378697729\" target=\"_blank\" rel=\"nofollow ugc noopener\">Effin' Birds</a></h4>\n<div class=\"twitter-screen-name\"><a href=\"https://twitter.com/EffinBirds/status/1518743508378697729\" target=\"_blank\" rel=\"nofollow ugc noopener\">@EffinBirds</a></div>\n\n<div class=\"tweet\">\n  <span class=\"tweet-description\">https://t.co/LjlqMm9lck</span>\n</div>\n\n<div class=\"date\">\n  <a href=\"https://twitter.com/EffinBirds/status/1518743508378697729\" class=\"timestamp\" target=\"_blank\" rel=\"nofollow ugc noopener\">5:07 PM - 25 Apr 2022</a>\n\n    <span class=\"like\">\n      <svg viewbox=\"0 0 512 512\" width=\"14px\" height=\"16px\" aria-hidden=\"true\">\n        <path d=\"M462.3 62.6C407.5 15.9 326 24.3 275.7 76.2L256 96.5l-19.7-20.3C186.1 24.3 104.5 15.9 49.7 62.6c-62.8 53.6-66.1 149.8-9.9 207.9l193.5 199.8c12.5 12.9 32.8 12.9 45.3 0l193.5-199.8c56.3-58.1 53-154.3-9.8-207.9z\"></path>\n      </svg>\n      2.5K\n    </span>\n\n    <span class=\"retweet\">\n      <svg viewbox=\"0 0 640 512\" width=\"14px\" height=\"16px\" aria-hidden=\"true\">\n        <path d=\"M629.657 343.598L528.971 444.284c-9.373 9.372-24.568 9.372-33.941 0L394.343 343.598c-9.373-9.373-9.373-24.569 0-33.941l10.823-10.823c9.562-9.562 25.133-9.34 34.419.492L480 342.118V160H292.451a24.005 24.005 0 0 1-16.971-7.029l-16-16C244.361 121.851 255.069 96 276.451 96H520c13.255 0 24 10.745 24 24v222.118l40.416-42.792c9.285-9.831 24.856-10.054 34.419-.492l10.823 10.823c9.372 9.372 9.372 24.569-.001 33.941zm-265.138 15.431A23.999 23.999 0 0 0 347.548 352H160V169.881l40.416 42.792c9.286 9.831 24.856 10.054 34.419.491l10.822-10.822c9.373-9.373 9.373-24.569 0-33.941L144.971 67.716c-9.373-9.373-24.569-9.373-33.941 0L10.343 168.402c-9.373 9.373-9.373 24.569 0 33.941l10.822 10.822c9.562 9.562 25.133 9.34 34.419-.491L96 169.881V392c0 13.255 10.745 24 24 24h243.549c21.382 0 32.09-25.851 16.971-40.971l-16.001-16z\"></path>\n      </svg>\n      499\n    </span>\n</div>\n\n  </article>\n\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n\n  <div style=\"clear: both\"></div>\n</aside>\n
        COOKED
        )
      expect(message.build_excerpt).to eq(
        "https://twitter.com/EffinBirds/status/1518743508378697729",
      )
    end

    it "excerpts upload file name if message is empty" do
      gif =
        Fabricate(:upload, original_filename: "cat.gif", width: 400, height: 300, extension: "gif")
      message = Fabricate(:chat_message, message: "", uploads: [gif])

      expect(message.build_excerpt).to eq "cat.gif"
    end

    it "supports autolink with <>" do
      cooked = described_class.cook("<https://github.com/discourse/discourse-chat/pull/468>")

      expect(cooked).to eq(
        "<p><a href=\"https://github.com/discourse/discourse-chat/pull/468\" rel=\"noopener nofollow ugc\">https://github.com/discourse/discourse-chat/pull/468</a></p>",
      )
    end

    it "supports lists" do
      cooked = described_class.cook(<<~MSG)
      wow look it's a list

      * item 1
      * item 2
      MSG

      expect(cooked).to eq(<<~HTML.chomp)
      <p>wow look it's a list</p>
      <ul>
      <li>item 1</li>
      <li>item 2</li>
      </ul>
      HTML
    end

    it "supports inline emoji" do
      cooked = described_class.cook(":D")
      expect(cooked).to eq(<<~HTML.chomp)
      <p><img src="/images/emoji/twitter/smiley.png?v=12" title=":smiley:" class="emoji only-emoji" alt=":smiley:" loading=\"lazy\" width=\"20\" height=\"20\"></p>
      HTML
    end

    it "supports emoji shortcuts" do
      cooked = described_class.cook("this is a replace test :P :|")
      expect(cooked).to eq(<<~HTML.chomp)
        <p>this is a replace test <img src="/images/emoji/twitter/stuck_out_tongue.png?v=12" title=":stuck_out_tongue:" class="emoji" alt=":stuck_out_tongue:" loading=\"lazy\" width=\"20\" height=\"20\"> <img src="/images/emoji/twitter/expressionless.png?v=12" title=":expressionless:" class="emoji" alt=":expressionless:" loading=\"lazy\" width=\"20\" height=\"20\"></p>
      HTML
    end

    it "supports spoilers" do
      if SiteSetting.respond_to?(:spoiler_enabled) && SiteSetting.spoiler_enabled
        cooked =
          described_class.cook("[spoiler]the planet of the apes was earth all along[/spoiler]")

        expect(cooked).to eq(
          "<div class=\"spoiler\">\n<p>the planet of the apes was earth all along</p>\n</div>",
        )
      end
    end

    context "when unicode usernames are enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "cooks unicode mentions" do
        user = Fabricate(:unicode_user)
        cooked = described_class.cook("<h1>@#{user.username}</h1>")

        expect(cooked).to eq("<p>&lt;h1&gt;@#{user.username}&lt;/h1&gt;</p>")
      end
    end
  end

  describe ".to_markdown" do
    it "renders the message without uploads" do
      expect(message.to_markdown).to eq("hey friend, what's up?!")
    end

    it "renders the message with uploads" do
      image =
        Fabricate(
          :upload,
          original_filename: "test_image.jpg",
          width: 400,
          height: 300,
          extension: "jpg",
        )
      image2 =
        Fabricate(:upload, original_filename: "meme.jpg", width: 10, height: 10, extension: "jpg")
      message.uploads = [image, image2]
      expect(message.to_markdown).to eq(<<~MSG.chomp)
      hey friend, what's up?!

      ![test_image.jpg|400x300](#{image.short_url})
      ![meme.jpg|10x10](#{image2.short_url})
      MSG
    end
  end

  describe ".push_notification_excerpt" do
    it "truncates to 400 characters" do
      message = described_class.new(message: "Hello, World!" * 40)
      expect(message.push_notification_excerpt.size).to eq(400)
    end

    it "encodes emojis" do
      message = described_class.new(message: ":grinning:")
      expect(message.push_notification_excerpt).to eq("😀")
    end
  end

  describe "blocking duplicate messages" do
    fab!(:channel) { Fabricate(:chat_channel, user_count: 10) }
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }

    before { SiteSetting.chat_duplicate_message_sensitivity = 1 }

    it "blocks duplicate messages for the message, channel user, and message age requirements" do
      Fabricate(:chat_message, message: "this is duplicate", chat_channel: channel, user: user1)
      message =
        described_class.new(message: "this is duplicate", chat_channel: channel, user: user2)
      message.valid?
      expect(message.errors.full_messages).to include(I18n.t("chat.errors.duplicate_message"))
    end
  end

  describe "#destroy" do
    it "nullify messages with in_reply_to_id to this destroyed message" do
      message_1 = Fabricate(:chat_message)
      message_2 = Fabricate(:chat_message, in_reply_to_id: message_1.id)
      message_3 = Fabricate(:chat_message, in_reply_to_id: message_2.id)

      expect(message_2.in_reply_to_id).to eq(message_1.id)

      message_1.destroy!

      expect(message_2.reload.in_reply_to_id).to be_nil
      expect(message_3.reload.in_reply_to_id).to eq(message_2.id)
    end

    it "destroys chat_message_revisions" do
      message_1 = Fabricate(:chat_message)
      revision_1 = Fabricate(:chat_message_revision, chat_message: message_1)

      message_1.destroy!

      expect { revision_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "destroys chat_message_reactions" do
      message_1 = Fabricate(:chat_message)
      reaction_1 = Fabricate(:chat_message_reaction, chat_message: message_1)

      message_1.destroy!

      expect { reaction_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "destroys chat_mention" do
      message_1 = Fabricate(:chat_message)
      notification = Fabricate(:notification, notification_type: Notification.types[:chat_mention])
      mention_1 =
        Fabricate(:user_chat_mention, chat_message: message_1, notifications: [notification])

      message_1.reload.destroy!

      expect { mention_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "destroys chat_webhook_event" do
      message_1 = Fabricate(:chat_message)
      webhook_1 = Fabricate(:chat_webhook_event, chat_message: message_1)

      # Need to reload because chat_webhook_event instantiates the message
      # before the relationship is created
      message_1.reload.destroy!

      expect { webhook_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "destroys upload_references" do
      message_1 = Fabricate(:chat_message)
      upload_reference_1 = Fabricate(:upload_reference, target: message_1)
      _upload_1 = Fabricate(:upload)

      message_1.destroy!

      expect { upload_reference_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    describe "bookmarks" do
      before { register_test_bookmarkable(Chat::MessageBookmarkable) }

      after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

      it "destroys bookmarks" do
        message_1 = Fabricate(:chat_message)
        bookmark_1 = Fabricate(:bookmark, bookmarkable: message_1)

        message_1.reload.destroy!

        expect { bookmark_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#rebake!" do
    fab!(:chat_message)

    describe "hashtags" do
      fab!(:category)
      fab!(:group)
      fab!(:secure_category) { Fabricate(:private_category, group: group) }

      before do
        SiteSetting.chat_enabled = true
        SiteSetting.suppress_secured_categories_from_admin = true
      end

      it "keeps the same hashtags the user has permission to after rebake" do
        group.add(chat_message.user)
        chat_message.chat_channel.add(chat_message.user)

        update_message!(
          chat_message,
          user: chat_message.user,
          text:
            "this is the message ##{category.slug} ##{secure_category.slug} ##{chat_message.chat_channel.slug}",
        )

        expect(chat_message.reload.cooked).to include(secure_category.name)

        chat_message.rebake!

        expect(chat_message.reload.cooked).to include(secure_category.name)
      end
    end
  end

  describe "#upsert_mentions" do
    context "with direct mentions" do
      fab!(:user1) { Fabricate(:user) }
      fab!(:user2) { Fabricate(:user) }
      fab!(:user3) { Fabricate(:user) }
      fab!(:user4) { Fabricate(:user) }
      fab!(:message) do
        Fabricate(:chat_message, message: "Hey @#{user1.username} and @#{user2.username}")
      end
      let(:already_mentioned) { [user1.id, user2.id] }

      it "creates newly added mentions" do
        existing_mention_ids = message.chat_mentions.pluck(:id)
        message.message = message.message + " @#{user3.username} @#{user4.username} "
        message.cook

        message.upsert_mentions

        expect(message.user_mentions.pluck(:target_id)).to match_array(
          [user1.id, user2.id, user3.id, user4.id],
        )
        expect(message.user_mentions.pluck(:id)).to include(*existing_mention_ids) # existing mentions weren't recreated
      end

      it "drops removed mentions" do
        # user 2 is not mentioned anymore:
        message.message = "Hey @#{user1.username}"
        message.cook

        message.upsert_mentions

        expect(message.user_mentions.pluck(:target_id)).to contain_exactly(user1.id)
      end

      it "changes nothing if message mentions has not been changed" do
        existing_mention_ids = message.chat_mentions.pluck(:id)

        message.upsert_mentions

        expect(message.user_mentions.pluck(:target_id)).to match_array(already_mentioned)
        expect(message.user_mentions.pluck(:id)).to include(*existing_mention_ids) # the mentions weren't recreated
      end
    end

    context "with group mentions" do
      fab!(:group1) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:group2) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:group3) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:group4) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:message) do
        Fabricate(:chat_message, message: "Hey @#{group1.name} and @#{group2.name}")
      end
      let(:already_mentioned) { [group1.id, group2.id] }

      it "creates newly added mentions" do
        existing_mention_ids = message.chat_mentions.pluck(:id)
        message.message = message.message + " @#{group3.name} @#{group4.name} "
        message.cook

        message.upsert_mentions

        expect(message.group_mentions.pluck(:target_id)).to match_array(
          [group1.id, group2.id, group3.id, group4.id],
        )
        expect(message.group_mentions.pluck(:id)).to include(*existing_mention_ids) # existing mentions weren't recreated
      end

      it "drops removed mentions" do
        # group 2 is not mentioned anymore:
        message.message = "Hey @#{group1.name}"
        message.cook

        message.upsert_mentions

        expect(message.group_mentions.pluck(:target_id)).to contain_exactly(group1.id)
      end

      it "changes nothing if message mentions has not been changed" do
        existing_mention_ids = message.chat_mentions.pluck(:id)

        message.upsert_mentions

        expect(message.group_mentions.pluck(:target_id)).to match_array(already_mentioned)
        expect(message.group_mentions.pluck(:id)).to include(*existing_mention_ids) # the mentions weren't recreated
      end
    end

    context "with @here mentions" do
      fab!(:message) { Fabricate(:chat_message, message: "There are no mentions yet") }

      it "creates @here mention" do
        message.message = "Mentioning @here"
        message.cook

        message.upsert_mentions

        expect(message.here_mention).to be_present
      end

      it "creates only one mention even if @here present more than once in a message" do
        message.message = "Mentioning several times: @here @here @here"
        message.cook

        message.upsert_mentions

        expect(message.here_mention).to be_present
        expect(message.chat_mentions.count).to be(1)
      end

      it "drops @here mention when it's dropped from the message" do
        message.message = "Mentioning @here"
        message.cook
        message.upsert_mentions

        message.message = "No mentions now"
        message.cook

        message.upsert_mentions

        expect(message.here_mention).to be_blank
      end
    end

    context "with @all mentions" do
      fab!(:message) { Fabricate(:chat_message, message: "There are no mentions yet") }

      it "creates @all mention" do
        message.message = "Mentioning @all"
        message.cook

        message.upsert_mentions

        expect(message.all_mention).to be_present
      end

      it "creates only one mention even if @here present more than once in a message" do
        message.message = "Mentioning several times: @all @all @all"
        message.cook

        message.upsert_mentions

        expect(message.all_mention).to be_present
        expect(message.chat_mentions.count).to be(1)
      end

      it "drops @here mention when it's dropped from the message" do
        message.message = "Mentioning @all"
        message.cook
        message.upsert_mentions

        message.message = "No mentions now"
        message.cook

        message.upsert_mentions

        expect(message.all_mention).to be_blank
      end
    end
  end

  describe "#url" do
    it "returns message permalink" do
      expect(message.url).to eq("/chat/c/-/#{message.chat_channel_id}/#{message.id}")
    end

    it "returns message permalink when in thread" do
      thread = Fabricate(:chat_thread)
      first_message = thread.chat_messages.first
      expect(first_message.url).to eq(
        "/chat/c/-/#{first_message.chat_channel_id}/t/#{first_message.thread_id}/#{first_message.id}",
      )
    end
  end
end
