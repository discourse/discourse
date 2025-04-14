# frozen_string_literal: true

describe Chat::TranscriptService do
  let(:acting_user) { Fabricate(:user) }
  let(:user1) { Fabricate(:user, username: "martinchat") }
  let(:user2) { Fabricate(:user, username: "brucechat") }
  let(:channel) do
    Fabricate(:category_channel, name: "The Beam Discussions", threading_enabled: true)
  end

  def service(message_ids, opts: {})
    described_class.new(channel, acting_user, messages_or_ids: Array.wrap(message_ids), opts: opts)
  end

  it "generates a simple chat transcript from one message" do
    message =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )

    expect(service(message.id).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message.id};#{message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}"]
    an extremely insightful response :)
    [/chat]
    MARKDOWN
  end

  it "generates a single chat transcript from multiple subsequent messages from the same user" do
    message1 =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    message2 =
      Fabricate(:chat_message, user: user1, chat_channel: channel, message: "if i say so myself")
    message3 = Fabricate(:chat_message, user: user1, chat_channel: channel, message: "yay!")

    rendered = service([message1.id, message2.id, message3.id]).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message1.id};#{message1.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true"]
    an extremely insightful response :)

    if i say so myself

    yay!
    [/chat]
    MARKDOWN
  end

  it "generates chat messages in created_at order no matter what order the message_ids are passed in" do
    message1 =
      Fabricate(
        :chat_message,
        created_at: 10.minute.ago,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    message2 =
      Fabricate(
        :chat_message,
        created_at: 5.minutes.ago,
        user: user1,
        chat_channel: channel,
        message: "if i say so myself",
      )
    message3 =
      Fabricate(
        :chat_message,
        created_at: 1.minutes.ago,
        user: user1,
        chat_channel: channel,
        message: "yay!",
      )

    rendered = service([message3.id, message1.id, message2.id]).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message1.id};#{message1.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true"]
    an extremely insightful response :)

    if i say so myself

    yay!
    [/chat]
    MARKDOWN
  end

  it "generates multiple chained chat transcripts for interleaving messages from different users" do
    message1 =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    message2 = Fabricate(:chat_message, user: user2, chat_channel: channel, message: "says you!")
    message3 = Fabricate(:chat_message, user: user1, chat_channel: channel, message: "aw :(")

    expect(service([message1.id, message2.id, message3.id]).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message1.id};#{message1.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true"]
    an extremely insightful response :)
    [/chat]

    [chat quote="brucechat;#{message2.id};#{message2.created_at.iso8601}" chained="true"]
    says you!
    [/chat]

    [chat quote="martinchat;#{message3.id};#{message3.created_at.iso8601}" chained="true"]
    aw :(
    [/chat]
    MARKDOWN
  end

  it "generates image / attachment / video / audio markdown inside the [chat] bbcode for upload-only messages" do
    SiteSetting.authorized_extensions = "mp4|mp3|pdf|jpg"
    video = Fabricate(:upload, original_filename: "test_video.mp4", extension: "mp4")
    audio = Fabricate(:upload, original_filename: "test_audio.mp3", extension: "mp3")
    attachment = Fabricate(:upload, original_filename: "test_file.pdf", extension: "pdf")
    image =
      Fabricate(
        :upload,
        width: 100,
        height: 200,
        original_filename: "test_img.jpg",
        extension: "jpg",
      )
    message =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "",
        uploads: [video, audio, attachment, image],
      )
    video_markdown = UploadMarkdown.new(video).to_markdown
    audio_markdown = UploadMarkdown.new(audio).to_markdown
    attachment_markdown = UploadMarkdown.new(attachment).to_markdown
    image_markdown = UploadMarkdown.new(image).to_markdown

    expect(service(message.id).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message.id};#{message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}"]
    #{video_markdown}
    #{audio_markdown}
    #{attachment_markdown}
    #{image_markdown}
    [/chat]
    MARKDOWN
  end

  it "generates the correct markdown for messages that are in reply to other messages" do
    channel.update!(threading_enabled: false)
    thread = Fabricate(:chat_thread, channel: channel)

    message1 =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        thread: thread,
        message: "an extremely insightful response :)",
      )
    message2 = Fabricate(:chat_message, user: user2, chat_channel: channel, message: "says you!")
    message3 =
      Fabricate(:chat_message, user: user1, chat_channel: channel, thread: thread, message: "aw :(")

    expect(service([message1.id, message2.id, message3.id]).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message1.id};#{message1.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true"]
    an extremely insightful response :)
    [/chat]

    [chat quote="brucechat;#{message2.id};#{message2.created_at.iso8601}" chained="true"]
    says you!
    [/chat]

    [chat quote="martinchat;#{message3.id};#{message3.created_at.iso8601}" chained="true"]
    aw :(
    [/chat]
    MARKDOWN
  end

  it "generates the correct markdown if a message has text and an upload" do
    SiteSetting.authorized_extensions = "mp4|mp3|pdf|jpg"
    message =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "this is a cool and funny picture",
      )
    image =
      Fabricate(
        :upload,
        width: 100,
        height: 200,
        original_filename: "test_img.jpg",
        extension: "jpg",
      )
    UploadReference.create(target: message, created_at: 7.seconds.ago, upload: image)
    image_markdown = UploadMarkdown.new(image).to_markdown

    expect(service(message.id).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message.id};#{message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}"]
    this is a cool and funny picture

    #{image_markdown}
    [/chat]
    MARKDOWN
  end

  it "generates a transcript with the noLink option" do
    message =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )

    expect(service(message.id, opts: { no_link: true }).generate_markdown).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message.id};#{message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" noLink="true"]
    an extremely insightful response :)
    [/chat]
    MARKDOWN
  end

  it "generates reaction data for single and subsequent messages" do
    message =
      Fabricate(
        :chat_message,
        user: user1,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    message2 = Fabricate(:chat_message, user: user1, chat_channel: channel, message: "wow so tru")
    message3 =
      Fabricate(:chat_message, user: user2, chat_channel: channel, message: "a new perspective")

    Chat::MessageReaction.create!(
      chat_message: message,
      user: Fabricate(:user, username: "bjorn"),
      emoji: "heart",
    )
    Chat::MessageReaction.create!(
      chat_message: message,
      user: Fabricate(:user, username: "sigurd"),
      emoji: "heart",
    )
    Chat::MessageReaction.create!(
      chat_message: message,
      user: Fabricate(:user, username: "hvitserk"),
      emoji: "+1",
    )
    Chat::MessageReaction.create!(
      chat_message: message2,
      user: Fabricate(:user, username: "ubbe"),
      emoji: "money_mouth_face",
    )
    Chat::MessageReaction.create!(
      chat_message: message3,
      user: Fabricate(:user, username: "ivar"),
      emoji: "sob",
    )

    expect(
      service(
        [message.id, message2.id, message3.id],
        opts: {
          include_reactions: true,
        },
      ).generate_markdown,
    ).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{message.id};#{message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true" reactions="+1:hvitserk;heart:bjorn,sigurd;money_mouth_face:ubbe"]
    an extremely insightful response :)

    wow so tru
    [/chat]

    [chat quote="brucechat;#{message3.id};#{message3.created_at.iso8601}" chained="true" reactions="sob:ivar"]
    a new perspective
    [/chat]
    MARKDOWN
  end

  it "generates reaction data for threaded messages" do
    thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(
            :chat_message,
            chat_channel: channel,
            user: user1,
            message: "an extremely insightful response :)",
          ),
      )
    thread_reply_1 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user2,
        thread: thread,
        message: "wow so tru",
      )
    thread_reply_2 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread,
        message: "a new perspective",
      )

    Chat::MessageReaction.create!(
      chat_message: thread.original_message,
      user: Fabricate(:user, username: "bjorn"),
      emoji: "heart",
    )
    Chat::MessageReaction.create!(
      chat_message: thread_reply_1,
      user: Fabricate(:user, username: "sigurd"),
      emoji: "heart",
    )
    Chat::MessageReaction.create!(
      chat_message: thread_reply_1,
      user: Fabricate(:user, username: "hvitserk"),
      emoji: "+1",
    )
    Chat::MessageReaction.create!(
      chat_message: thread_reply_2,
      user: Fabricate(:user, username: "ubbe"),
      emoji: "money_mouth_face",
    )

    thread.update!(replies_count: 2)
    rendered =
      service(
        [thread.original_message.id, thread_reply_1.id, thread_reply_2.id],
        opts: {
          include_reactions: true,
        },
      ).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{thread.original_message.id};#{thread.original_message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true" reactions="heart:bjorn" threadId="#{thread.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    an extremely insightful response :)

    [chat quote="brucechat;#{thread_reply_1.id};#{thread_reply_1.created_at.iso8601}" chained="true" reactions="+1:hvitserk;heart:sigurd"]
    wow so tru
    [/chat]

    [chat quote="martinchat;#{thread_reply_2.id};#{thread_reply_2.created_at.iso8601}" chained="true" reactions="money_mouth_face:ubbe"]
    a new perspective
    [/chat]

    [/chat]
    MARKDOWN
  end

  it "generates a chat transcript for threaded messages" do
    thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(:chat_message, chat_channel: channel, user: user1, message: "reply to me!"),
      )
    thread_reply_1 =
      Fabricate(:chat_message, chat_channel: channel, user: user2, thread: thread, message: "done")
    thread_reply_2 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread,
        message: "thanks",
      )
    thread.update!(replies_count: 2)
    rendered =
      service([thread.original_message.id, thread_reply_1.id, thread_reply_2.id]).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{thread.original_message.id};#{thread.original_message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true" threadId="#{thread.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    reply to me!

    [chat quote="brucechat;#{thread_reply_1.id};#{thread_reply_1.created_at.iso8601}" chained="true"]
    done
    [/chat]

    [chat quote="martinchat;#{thread_reply_2.id};#{thread_reply_2.created_at.iso8601}" chained="true"]
    thanks
    [/chat]

    [/chat]
    MARKDOWN
  end

  it "includes all of the thread replies if only one message is supplied, and it is the thread OP" do
    thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(:chat_message, chat_channel: channel, user: user1, message: "reply to me!"),
      )
    thread_reply_1 =
      Fabricate(:chat_message, chat_channel: channel, user: user2, thread: thread, message: "done")
    thread_reply_2 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread,
        message: "thanks",
      )
    thread.update!(original_message_id: thread.original_message.id, replies_count: 2)
    rendered = service([thread.original_message.id]).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{thread.original_message.id};#{thread.original_message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true" threadId="#{thread.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    reply to me!

    [chat quote="brucechat;#{thread_reply_1.id};#{thread_reply_1.created_at.iso8601}" chained="true"]
    done
    [/chat]

    [chat quote="martinchat;#{thread_reply_2.id};#{thread_reply_2.created_at.iso8601}" chained="true"]
    thanks
    [/chat]

    [/chat]
    MARKDOWN
  end

  it "does not chain replies if the thread messages are all by the same user" do
    thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(:chat_message, chat_channel: channel, user: user1, message: "reply to me!"),
      )
    thread_reply_1 =
      Fabricate(:chat_message, chat_channel: channel, user: user1, thread: thread, message: "done")
    thread_reply_2 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread,
        message: "thanks",
      )
    thread.update!(original_message_id: thread.original_message.id, replies_count: 2)
    rendered = service([thread.original_message.id]).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{thread.original_message.id};#{thread.original_message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" threadId="#{thread.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    reply to me!

    [chat quote="martinchat;#{thread_reply_1.id};#{thread_reply_1.created_at.iso8601}"]
    done

    thanks
    [/chat]

    [/chat]
    MARKDOWN
  end

  it "doesn't add thread info for threads with no replies" do
    thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(:chat_message, chat_channel: channel, user: user1, message: "has a reply"),
      )
    thread_message =
      Fabricate(
        :chat_message,
        user: user2,
        chat_channel: channel,
        message: "a reply",
        thread: thread,
      )
    empty_thread =
      Fabricate(
        :chat_thread,
        channel: channel,
        original_message:
          Fabricate(
            :chat_message,
            chat_channel: channel,
            user: user1,
            thread:,
            message: "no replies",
          ),
      )

    thread.update!(replies_count: 1)
    rendered =
      service(
        [thread.original_message.id, thread_message.id, empty_thread.original_message.id],
      ).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{thread.original_message.id};#{thread.original_message.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true" threadId="#{thread.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    has a reply

    [chat quote="brucechat;#{thread_message.id};#{thread_message.created_at.iso8601}" chained="true"]
    a reply
    [/chat]

    [/chat]

    [chat quote="martinchat;#{empty_thread.original_message.id};#{empty_thread.original_message.created_at.iso8601}" chained="true"]
    no replies
    [/chat]
    MARKDOWN
  end

  xit "generates the correct markdown for multiple threads" do
    channel_message_1 =
      Fabricate(:chat_message, user: user1, chat_channel: channel, message: "I need ideas")
    thread_1 = Fabricate(:chat_thread, channel: channel)
    thread_1_om =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user2,
        thread: thread_1,
        message: "this is my idea",
      )
    thread_1_message =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread_1,
        message: "cool",
      )

    channel_message_2 =
      Fabricate(:chat_message, user: user2, chat_channel: channel, message: "more?")
    thread_2 = Fabricate(:chat_thread, channel: channel, title: "the second idea")
    thread_2_om =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user2,
        thread: thread_2,
        message: "another one",
      )
    thread_2_message_1 =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user1,
        thread: thread_2,
        message: "thanks",
      )
    thread_2_message_2 =
      Fabricate(:chat_message, chat_channel: channel, user: user2, thread: thread_2, message: "np")

    thread_1.update!(replies_count: 1)
    thread_2.update!(replies_count: 2)
    rendered =
      service(
        [
          channel_message_1.id,
          thread_1_om.id,
          thread_1_message.id,
          channel_message_2.id,
          thread_2_om.id,
          thread_2_message_1.id,
          thread_2_message_2.id,
        ],
      ).generate_markdown
    expect(rendered).to eq(<<~MARKDOWN)
    [chat quote="martinchat;#{channel_message_1.id};#{channel_message_1.created_at.iso8601}" channel="The Beam Discussions" channelId="#{channel.id}" multiQuote="true" chained="true"]
    I need ideas
    [/chat]

    [chat quote="brucechat;#{thread_1_om.id};#{thread_1_om.created_at.iso8601}" chained="true" threadId="#{thread_1.id}" threadTitle="#{I18n.t("chat.transcript.default_thread_title")}"]
    this is my idea

    [chat quote="martinchat;#{thread_1_message.id};#{thread_1_message.created_at.iso8601}" chained="true"]
    cool
    [/chat]

    [/chat]

    [chat quote="brucechat;#{channel_message_2.id};#{channel_message_2.created_at.iso8601}" chained="true"]
    more?
    [/chat]

    [chat quote="brucechat;#{thread_2_om.id};#{thread_2_om.created_at.iso8601}" chained="true" threadId="#{thread_2.id}" threadTitle="the second idea"]
    another one

    [chat quote="martinchat;#{thread_2_message_1.id};#{thread_2_message_1.created_at.iso8601}" chained="true"]
    thanks
    [/chat]

    [chat quote="brucechat;#{thread_2_message_2.id};#{thread_2_message_2.created_at.iso8601}" chained="true"]
    np
    [/chat]

    [/chat]
    MARKDOWN
  end
end
