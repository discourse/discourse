# frozen_string_literal: true

RSpec.describe Chat::ChatController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)
  fab!(:category)
  fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }
  fab!(:dm_chat_channel) { Fabricate(:direct_message_channel, users: [user, other_user, admin]) }
  fab!(:tag)

  MESSAGE_COUNT = 70
  MESSAGE_COUNT.times do |n|
    fab!("message_#{n}") do
      Fabricate(
        :chat_message,
        chat_channel: chat_channel,
        user: other_user,
        message: "message #{n}",
      )
    end
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def flag_message(message, flagger, flag_type: ReviewableScore.types[:off_topic])
    Chat::ReviewQueue.new.flag_message(message, Guardian.new(flagger), flag_type)[:reviewable]
  end

  describe "#rebake" do
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }

    it "rebakes the message" do
      sign_in(admin)
      put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
      expect(response.status).to eq(200)
    end

    context "when message does not exist" do
      it "returns a 404" do
        sign_in(admin)
        put "/chat/#{chat_channel.id}/-999/rebake.json"
        expect(response.status).to eq(404)
      end
    end

    context "when channel does not exist" do
      it "returns a 404" do
        sign_in(admin)
        put "/chat/-999/#{chat_message.id}/rebake.json"
        expect(response.status).to eq(404)
      end
    end

    context "when user cannot access the channel" do
      fab!(:inaccessible_channel, :private_category_channel)

      it "returns a 403" do
        sign_in(Fabricate(:user))
        put "/chat/#{inaccessible_channel.id}/-999/rebake.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user cannot rebake" do
      it "returns a 403" do
        sign_in(Fabricate(:user))
        put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "react" do
    fab!(:chat_channel, :category_channel)
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }
    fab!(:user_membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user)
    end

    fab!(:private_chat_channel) do
      Fabricate(:category_channel, chatable: Fabricate(:private_category, group: Fabricate(:group)))
    end
    fab!(:private_chat_message) do
      Fabricate(:chat_message, chat_channel: private_chat_channel, user: admin)
    end
    fab!(:private_user_membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: private_chat_channel, user: user)
    end

    fab!(:chat_channel_no_memberships, :category_channel)
    fab!(:chat_message_no_memberships) do
      Fabricate(:chat_message, chat_channel: chat_channel_no_memberships, user: user)
    end

    it "errors with invalid emoji" do
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: 12,
            react_action: "add",
          }
      expect(response.status).to eq(400)
    end

    it "errors with invalid action" do
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "sdf",
          }
      expect(response.status).to eq(400)
    end

    it "errors when reacting to channel without a membership record" do
      sign_in(user)

      expect {
        put "/chat/#{chat_channel_no_memberships.id}/react/#{chat_message_no_memberships.id}.json",
            params: {
              emoji: ":heart:",
              react_action: "add",
            }
      }.not_to change { Chat::UserChatChannelMembership.count }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(I18n.t("chat.errors.user_not_in_channel"))
    end

    it "errors when user tries to react to private channel they can't access" do
      sign_in(user)
      put "/chat/#{private_chat_channel.id}/react/#{private_chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
    end

    it "errors when the user tries to react to a read_only channel" do
      chat_channel.update(status: :read_only)
      sign_in(user)
      emoji = ":heart:"
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "add",
            }
      }.not_to change { chat_message.reactions.where(user: user, emoji: emoji).count }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("chat.errors.channel_modify_message_disallowed.#{chat_channel.status}"),
      )
    end

    it "errors when user is silenced" do
      UserSilencer.new(user).silence
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
    end

    it "errors when max unique reactions limit is reached" do
      Emoji
        .all
        .map(&:name)
        .take(29)
        .each { |emoji| chat_message.reactions.create(user: user, emoji: emoji) }

      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":wink:",
            react_action: "add",
          }
      expect(response.status).to eq(200)

      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":waving_hand:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("chat.errors.max_reactions_limit_reached"),
      )
    end

    it "does not error on new duplicate reactions" do
      another_user = Fabricate(:user)
      Emoji
        .all
        .map(&:name)
        .take(29)
        .each { |emoji| chat_message.reactions.create(user: another_user, emoji: emoji) }
      emoji = ":wink:"
      chat_message.reactions.create(user: another_user, emoji: emoji)

      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: emoji,
            react_action: "add",
          }
      expect(response.status).to eq(200)
    end

    it "adds a reaction record correctly" do
      sign_in(user)
      emoji = ":heart:"
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "add",
            }
      }.to change { chat_message.reactions.where(user: user, emoji: emoji).count }.by(1)
      expect(response.status).to eq(200)
    end

    it "removes a reaction record correctly" do
      sign_in(user)
      emoji = ":heart:"
      chat_message.reactions.create(user: user, emoji: emoji)
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "remove",
            }
      }.to change { chat_message.reactions.where(user: user, emoji: emoji).count }.by(-1)
      expect(response.status).to eq(200)
    end
  end

  describe "#message_reactions_users" do
    fab!(:chat_channel, :category_channel)
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }
    fab!(:reactor_1, :user)
    fab!(:reactor_2, :user)

    # ordered by created_at: heart/reactor_1, heart/reactor_2, +1/reactor_1
    fab!(:heart_1) do
      Fabricate(:chat_message_reaction, chat_message: chat_message, user: reactor_1, emoji: "heart")
    end
    fab!(:heart_2) do
      Fabricate(:chat_message_reaction, chat_message: chat_message, user: reactor_2, emoji: "heart")
    end
    fab!(:thumbsup_1) do
      Fabricate(:chat_message_reaction, chat_message: chat_message, user: reactor_1, emoji: "+1")
    end

    it "returns all reactors with their emoji and the total count" do
      sign_in(user)
      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["total_rows"]).to eq(3)
      expect(
        response.parsed_body["users"].map { |reactor| [reactor["username"], reactor["reaction"]] },
      ).to eq(
        [[reactor_1.username, "heart"], [reactor_2.username, "heart"], [reactor_1.username, "+1"]],
      )
    end

    it "serializes each reactor with the BasicUserSerializer fields plus the reaction" do
      sign_in(user)
      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].first).to eq(
        {
          "id" => reactor_1.id,
          "username" => reactor_1.username,
          "name" => reactor_1.name,
          "avatar_template" => reactor_1.avatar_template,
          "reaction" => "heart",
        },
      )
    end

    it "filters by the emoji param" do
      sign_in(user)
      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json",
          params: {
            emoji: "heart",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["total_rows"]).to eq(2)
      expect(
        response.parsed_body["users"].map { |reactor| reactor["username"] },
      ).to contain_exactly(reactor_1.username, reactor_2.username)
    end

    it "paginates using page and limit" do
      sign_in(user)

      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json",
          params: {
            page: 0,
            limit: 1,
          }
      expect(response.parsed_body["total_rows"]).to eq(3)
      expect(response.parsed_body["users"].map { |reactor| reactor["username"] }).to eq(
        [reactor_1.username],
      )

      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json",
          params: {
            page: 1,
            limit: 1,
          }
      expect(response.parsed_body["users"].map { |reactor| reactor["username"] }).to eq(
        [reactor_2.username],
      )
    end

    it "excludes reactions from users the requester is ignoring" do
      Fabricate(:ignored_user, user: user, ignored_user: reactor_2)
      sign_in(user)

      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json"

      expect(response.parsed_body["total_rows"]).to eq(2)
      expect(response.parsed_body["users"].map { |reactor| reactor["username"] }).not_to include(
        reactor_2.username,
      )
    end

    it "returns a 404 when the message does not exist" do
      sign_in(user)
      get "/chat/#{chat_channel.id}/-999/reactions-users.json"
      expect(response.status).to eq(404)
    end

    it "returns a 404 when the message is trashed" do
      chat_message.trash!
      sign_in(user)
      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json"
      expect(response.status).to eq(404)
    end

    it "returns a 403 for anonymous users" do
      get "/chat/#{chat_channel.id}/#{chat_message.id}/reactions-users.json"
      expect(response.status).to eq(403)
    end

    it "returns a 403 when the channel is not accessible" do
      private_channel =
        Fabricate(
          :category_channel,
          chatable: Fabricate(:private_category, group: Fabricate(:group)),
        )
      private_message = Fabricate(:chat_message, chat_channel: private_channel, user: admin)

      sign_in(user)
      get "/chat/#{private_channel.id}/#{private_message.id}/reactions-users.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#dismiss_retention_reminder" do
    it "errors for anon" do
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      expect(response.status).to eq(403)
    end

    it "errors when chatable_type isn't present" do
      sign_in(user)
      post "/chat/dismiss-retention-reminder.json", params: {}
      expect(response.status).to eq(400)
    end

    it "errors when chatable_type isn't a valid option" do
      sign_in(user)
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "hi" }
      expect(response.status).to eq(400)
    end

    it "sets `dismissed_channel_retention_reminder` to true" do
      sign_in(user)
      expect {
        post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      }.to change { user.user_option.reload.dismissed_channel_retention_reminder }.to(true)
    end

    it "sets `dismissed_dm_retention_reminder` to true" do
      sign_in(user)
      expect {
        post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "DirectMessage" }
      }.to change { user.user_option.reload.dismissed_dm_retention_reminder }.to(true)
    end

    it "doesn't error if the fields are already true" do
      sign_in(user)
      user.user_option.update(
        dismissed_channel_retention_reminder: true,
        dismissed_dm_retention_reminder: true,
      )
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      expect(response.status).to eq(200)

      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "DirectMessage" }
      expect(response.status).to eq(200)
    end
  end

  describe "#quote_messages" do
    fab!(:channel) { Fabricate(:category_channel, chatable: category, name: "Cool Chat") }
    let(:user2) { Fabricate(:user) }
    let(:message1) do
      Fabricate(
        :chat_message,
        user: user,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    end
    let(:message2) do
      Fabricate(:chat_message, user: user2, chat_channel: channel, message: "says you!")
    end
    let(:message3) { Fabricate(:chat_message, user: user, chat_channel: channel, message: "aw :(") }

    it "returns a 403 if the user can't chat" do
      SiteSetting.chat_allowed_groups = ""
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(403)
    end

    it "returns a 403 if the user can't see the channel" do
      category.update!(read_restricted: true)
      group = Fabricate(:group)
      CategoryGroup.create(
        group: group,
        category: category,
        permission_type: CategoryGroup.permission_types[:create_post],
      )
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(403)
    end

    it "returns a 404 for a not found channel" do
      channel.destroy
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(404)
    end

    it "makes transcripts for the message ids provided" do
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(200)
      markdown = response.parsed_body["markdown"]
      expect(markdown).to eq(<<~EXPECTED)
      [chat quote="#{user.username};#{message1.id};#{message1.created_at.iso8601}" channel="Cool Chat" channelId="#{channel.id}" multiQuote="true" chained="true"]
      an extremely insightful response :)
      [/chat]

      [chat quote="#{user2.username};#{message2.id};#{message2.created_at.iso8601}" channelId="#{channel.id}" chained="true"]
      says you!
      [/chat]

      [chat quote="#{user.username};#{message3.id};#{message3.created_at.iso8601}" channelId="#{channel.id}" chained="true"]
      aw :(
      [/chat]
      EXPECTED
    end
  end

  describe "#respond" do
    let(:crawler_headers) { { "HTTP_USER_AGENT" => "Googlebot" } }
    let(:day) { message_0.created_at.utc.to_date.iso8601 }

    before do
      SiteSetting.chat_allowed_groups =
        "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    end

    it "renders the latest day of channel messages for crawlers" do
      get chat_channel.relative_url, headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(message_0.cooked, message_49.cooked)
      expect(response.body).not_to include(message_50.cooked)
      expect(response.body).to include(
        %(<link rel="canonical" href="#{chat_channel.url}?date=#{day}" />),
      )
      expect(response.body).to include(
        %(<link rel="next" href="#{chat_channel.url}?date=#{day}&amp;page=2">),
      )

      postings =
        Nokogiri.HTML5(response.body).css('[itemtype="http://schema.org/DiscussionForumPosting"]')
      expect(postings.size).to eq(50)
      expect(postings.first.at_css('link[itemprop="url"]')["href"]).to eq(
        "#{Discourse.base_url}#{message_0.url}",
      )
      expect(postings.first.at_css('[itemprop="author"] [itemprop="name"]').text).to eq(
        other_user.username,
      )
      expect(postings.first.at_css('[itemprop="text"]').inner_html.strip).to eq(message_0.cooked)
    end

    it "explains message retention when old messages are deleted" do
      SiteSetting.chat_channel_retention_days = 30
      get chat_channel.relative_url, headers: crawler_headers

      expect(response.body).to include(I18n.t("chat.crawler.retention_notice", count: 30))

      SiteSetting.chat_channel_retention_days = 0
      get chat_channel.relative_url, headers: crawler_headers

      expect(response.body).not_to include("chat-crawler__retention")
    end

    it "tells search engines when retention will remove a day page" do
      SiteSetting.chat_channel_retention_days = 30
      expected_expiry = (message_0.created_at.utc.to_date + 31).to_time(:utc).iso8601
      robots_meta = %(<meta name="robots" content="unavailable_after: #{expected_expiry}">)

      get "#{chat_channel.relative_url}?date=#{day}&page=2", headers: crawler_headers
      expect(response.body).to include(robots_meta)

      get chat_channel.relative_url, headers: crawler_headers
      expect(response.body).not_to include("unavailable_after")

      Fabricate(:chat_pinned_message, chat_message: message_0)
      get "#{chat_channel.relative_url}?date=#{day}", headers: crawler_headers
      expect(response.body).not_to include("unavailable_after")

      get "#{chat_channel.relative_url}?date=#{day}&page=2", headers: crawler_headers
      expect(response.body).to include(robots_meta)
    end

    it "counts each user who reacted to a message as one like" do
      Fabricate(:chat_message_reaction, chat_message: message_0, user:, emoji: "+1")
      Fabricate(:chat_message_reaction, chat_message: message_0, user:, emoji: "heart")
      Fabricate(:chat_message_reaction, chat_message: message_0, user: admin, emoji: "+1")

      get chat_channel.relative_url, headers: crawler_headers

      posting = Nokogiri.HTML5(response.body).at_css("#chat-message-#{message_0.id}")
      expect(
        posting.at_css('[itemprop="interactionStatistic"] meta[itemprop="userInteractionCount"]')[
          "content"
        ],
      ).to eq("2")
      expect(posting.css(".chat-crawler__reaction").map { |reaction| reaction.text.squish }).to eq(
        ["#{Emoji.lookup_unicode("+1")} 2", "#{Emoji.lookup_unicode("heart")} 1"],
      )
    end

    it "renders later pages of a day and 404s past the last one" do
      get "#{chat_channel.relative_url}?date=#{day}&page=2", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(message_50.cooked, message_69.cooked)
      expect(response.body).not_to include(message_49.cooked)
      expect(response.body).to include(%(<link rel="prev" href="#{chat_channel.url}?date=#{day}">))

      get "#{chat_channel.relative_url}?date=#{day}&page=3", headers: crawler_headers

      expect(response.status).to eq(404)
    end

    it "links between days that have messages" do
      old_message =
        Fabricate(:chat_message, chat_channel:, user: other_user, created_at: 3.days.ago)
      old_day = old_message.created_at.utc.to_date

      get "#{chat_channel.relative_url}?date=#{old_day.iso8601}", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(old_message.cooked)
      expect(response.body).not_to include(message_0.cooked)
      expect(response.body).to include(I18n.l(old_day, format: :date_only))
      expect(response.body).to include(%(<link rel="next" href="#{chat_channel.url}?date=#{day}">))

      get chat_channel.relative_url, headers: crawler_headers

      expect(response.body).not_to include(old_message.cooked)
      expect(response.body).to include(
        %(<link rel="prev" href="#{chat_channel.url}?date=#{old_day.iso8601}">),
      )
    end

    it "404s for invalid or empty days and missing messages" do
      get "#{chat_channel.relative_url}?date=not-a-date", headers: crawler_headers
      expect(response.status).to eq(404)

      get "#{chat_channel.relative_url}?date=2001-01-01", headers: crawler_headers
      expect(response.status).to eq(404)

      message_1.trash!
      get "#{chat_channel.relative_url}/#{message_1.id}", headers: crawler_headers
      expect(response.status).to eq(404)
    end

    it "renders the page containing a linked message with that page as canonical" do
      get "#{chat_channel.relative_url}/#{message_60.id}", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(message_60.cooked)
      expect(response.body).to include(
        %(<link rel="canonical" href="#{chat_channel.url}?date=#{day}&amp;page=2" />),
      )
    end

    it "links thread replies from the channel and renders them on the thread page" do
      chat_channel.update!(threading_enabled: true)
      thread = Fabricate(:chat_thread, channel: chat_channel, original_message: message_0)
      reply = Fabricate(:chat_message, chat_channel: chat_channel, thread:, message: "a reply")
      thread.update!(replies_count: 1)

      get chat_channel.relative_url, headers: crawler_headers

      expect(response.body).to include(%(href="#{thread.url}"))
      expect(response.body).not_to include(reply.cooked)

      channel_posting = Nokogiri.HTML5(response.body).at_css("#chat-message-#{message_0.id}")
      expect(channel_posting.at_css('link[itemprop="url"]')["href"]).to eq(thread.url)
      expect(channel_posting.at_css('meta[itemprop="commentCount"]')["content"]).to eq("1")

      get thread.relative_url, headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(message_0.cooked, reply.cooked)
      expect(response.body).not_to include(message_1.cooked)

      thread_posting =
        Nokogiri.HTML5(response.body).css('[itemtype="http://schema.org/DiscussionForumPosting"]')
      expect(thread_posting.size).to eq(1)
      expect(thread_posting.first.at_css('link[itemprop="url"]')["href"]).to eq(thread.url)
      expect(
        thread_posting.first.at_css('[itemprop="author"] meta[itemprop="name"]')["content"],
      ).to eq(other_user.username)
      expect(
        thread_posting.first.css('[itemprop="comment"]').map { |comment| comment["id"] },
      ).to eq(["chat-message-#{reply.id}"])
    end

    it "redirects channel permalinks of thread replies to the thread" do
      chat_channel.update!(threading_enabled: true)
      thread = Fabricate(:chat_thread, channel: chat_channel, original_message: message_0)
      reply = Fabricate(:chat_message, chat_channel: chat_channel, thread:)

      get "#{chat_channel.relative_url}/#{reply.id}", headers: crawler_headers

      expect(response).to redirect_to(reply.url)
      expect(response.status).to eq(301)

      get reply.url, headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(reply.cooked)
    end

    it "links forced threads when threading is off and 404s other threads" do
      forced_thread =
        Fabricate(:chat_thread, channel: chat_channel, original_message: message_0, force: true)
      Fabricate(:chat_message, chat_channel: chat_channel, thread: forced_thread)
      forced_thread.update!(replies_count: 1)
      thread = Fabricate(:chat_thread, channel: chat_channel, original_message: message_1)

      get chat_channel.relative_url, headers: crawler_headers

      expect(response.body).to include(%(href="#{forced_thread.url}"))

      get forced_thread.relative_url, headers: crawler_headers
      expect(response.status).to eq(200)

      get thread.relative_url, headers: crawler_headers
      expect(response.status).to eq(404)
    end

    it "handles malformed pagination params without erroring" do
      get "#{chat_channel.relative_url}?date=#{"1" * 200}", headers: crawler_headers
      expect(response.status).to eq(404)

      get "#{chat_channel.relative_url}?page[]=2", headers: crawler_headers
      expect(response.status).to eq(200)
      expect(response.body).to include(message_0.cooked)
    end

    it "renders the app shell for signed-in users on the crawler layout" do
      restricted_channel =
        Fabricate(
          :category_channel,
          chatable: Fabricate(:private_category, group: Fabricate(:group)),
        )
      restricted_message = Fabricate(:chat_message, chat_channel: restricted_channel)
      sign_in(admin)

      get "#{restricted_channel.relative_url}?print=true"

      expect(response.status).to eq(200)
      expect(response.body).not_to include(restricted_message.cooked)
    end

    it "404s for channels anonymous users cannot see" do
      restricted_channel =
        Fabricate(
          :category_channel,
          chatable: Fabricate(:private_category, group: Fabricate(:group)),
        )
      restricted_message = Fabricate(:chat_message, chat_channel: restricted_channel)
      dm_message = Fabricate(:chat_message, chat_channel: dm_chat_channel, user:)

      get restricted_channel.relative_url, headers: crawler_headers

      expect(response.status).to eq(404)
      expect(response.body).not_to include(restricted_message.cooked)

      get dm_chat_channel.relative_url, headers: crawler_headers

      expect(response.status).to eq(404)
      expect(response.body).not_to include(dm_message.cooked)
    end

    it "404s channels and renders an empty index when anonymous users are not allowed to chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]

      get chat_channel.relative_url, headers: crawler_headers

      expect(response.status).to eq(404)
      expect(response.body).not_to include(message_0.cooked)

      get "/chat", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).not_to include(chat_channel.url)
    end

    it "renders no messages for regular browsers" do
      get chat_channel.relative_url

      expect(response.status).to eq(200)
      expect(response.body).not_to include(message_0.cooked)
    end

    it "lists public channels in the directory for crawlers" do
      restricted_channel =
        Fabricate(
          :category_channel,
          name: "Secret plans",
          chatable: Fabricate(:private_category, group: Fabricate(:group)),
        )

      chat_channel.update!(last_message: message_69, messages_count: 70)

      get "/chat/browse", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).to include(
        %(<link rel="canonical" href="#{Discourse.base_url}/chat" />),
      )

      listed_channels =
        Nokogiri.HTML5(response.body).css(
          '[itemtype="http://schema.org/ItemList"] [itemprop="itemListElement"]',
        )
      expect(listed_channels.map { |item| item.at_css('[itemprop="url"]')["href"] }).to eq(
        [chat_channel.url],
      )
      expect(listed_channels.first.to_html).to include(
        category.name,
        I18n.t("chat.crawler.messages_count", count: 70),
        message_69.created_at.to_formatted_s(:iso8601),
      )
      expect(response.body).not_to include(restricted_channel.url)
    end

    it "paginates the directory" do
      stub_const(Chat::ChatController, :DIRECTORY_PAGE_SIZE, 1) do
        other_channel =
          Fabricate(:category_channel, name: "Zebra talk", chatable: Fabricate(:category))
        chat_channel.update!(name: "Aardvark talk")

        get "/chat", headers: crawler_headers

        expect(response.body).to include(chat_channel.url)
        expect(response.body).not_to include(other_channel.url)
        expect(response.body).to include(
          %(<link rel="next" href="#{Discourse.base_url}/chat?page=2">),
        )

        get "/chat?page=2", headers: crawler_headers

        expect(response.body).to include(other_channel.url)
        expect(response.body).to include(%(<link rel="prev" href="#{Discourse.base_url}/chat">))
        expect(response.body).to include(
          %(<link rel="canonical" href="#{Discourse.base_url}/chat?page=2" />),
        )

        get "/chat?page=3", headers: crawler_headers
        expect(response.status).to eq(404)
      end
    end
  end

  describe "crawler footer" do
    before do
      SiteSetting.chat_allowed_groups =
        "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    end

    it "links to chat when anonymous users can view chat" do
      get "/latest", headers: { "HTTP_USER_AGENT" => "Googlebot" }

      expect(response.body).to include(%(href='/chat' itemprop="url"))

      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      get "/latest", headers: { "HTTP_USER_AGENT" => "Googlebot" }

      expect(response.body).not_to include(%(href='/chat' itemprop="url"))
    end
  end
end
