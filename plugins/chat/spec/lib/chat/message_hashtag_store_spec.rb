# frozen_string_literal: true

RSpec.describe Chat::MessageHashtagStore do
  fab!(:channel) { Fabricate(:category_channel, slug: "support") }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def remap_channel(old_ref)
    HashtagRemapper.new(
      type: "channel",
      record_id: channel.id,
      old_ref:,
      new_ref: channel.reload.slug,
    ).remap!
  end

  describe "Chat::ChannelHashtagDataSource.ref_for" do
    it "returns the channel slug" do
      expect(Chat::ChannelHashtagDataSource.ref_for(channel.id)).to eq("support")
    end

    it "returns nothing for a trashed channel" do
      channel.trash!

      expect(Chat::ChannelHashtagDataSource.ref_for(channel.id)).to be_nil
    end
  end

  describe "the rename callback" do
    it "enqueues a remap when the slug changes" do
      expect_enqueued_with(
        job: :remap_hashtag,
        args: {
          remaps: [{ type: "channel", id: channel.id, old_ref: "support" }],
        },
      ) { channel.update!(slug: "help") }
    end

    it "does not enqueue a remap for unrelated changes" do
      expect_not_enqueued_with(job: :remap_hashtag) { channel.update!(description: "hello") }
    end

    it "does not rewrite anything to the tombstone slug when a channel is trashed" do
      post = create_post(raw: "See #support for details.")

      Chat::TrashChannel.call(
        params: {
          channel_id: channel.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      Jobs::RemapHashtag.new.execute(
        remaps: [{ "type" => "channel", "id" => channel.id, "old_ref" => "support" }],
      )

      expect(post.reload.raw).to eq("See #support for details.")
    end
  end

  describe "the chat message store" do
    it "rewrites a channel reference in a chat message" do
      message = Fabricate(:chat_message, chat_channel: channel, message: "See #support here.")

      expect(message.cooked).to include(%{data-type="channel"}, %{data-id="#{channel.id}"})

      channel.update!(slug: "help")
      remap_channel("support")

      message.reload
      expect(message.message).to eq("See #help here.")
      expect(message.cooked).to include(%{data-id="#{channel.id}"})
      expect(message.excerpt).to be_present
    end

    it "leaves a reference inside a code fence alone" do
      fenced =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          message: "Live #support\n\n```\nfence #support\n```",
        )

      channel.update!(slug: "help")
      remap_channel("support")

      expect(fenced.reload.message).to eq("Live #help\n\n```\nfence #support\n```")
    end
  end

  describe "across stores" do
    it "rewrites a channel reference in a post" do
      post = create_post(raw: "See #support for details.")

      expect(post.cooked).to include(%{data-type="channel"})

      channel.update!(slug: "help")
      remap_channel("support")

      expect(post.reload.raw).to eq("See #help for details.")
    end
  end
end
