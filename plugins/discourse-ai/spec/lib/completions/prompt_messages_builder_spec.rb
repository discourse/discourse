# frozen_string_literal: true

describe DiscourseAi::Completions::PromptMessagesBuilder do
  let(:builder) { DiscourseAi::Completions::PromptMessagesBuilder.new }
  fab!(:user)
  fab!(:admin)
  fab!(:bot_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  fab!(:image_upload1) do
    Fabricate(:upload, user: user, original_filename: "image.png", extension: "png")
  end
  fab!(:image_upload2) do
    Fabricate(:upload, user: user, original_filename: "image.png", extension: "png")
  end

  before { enable_current_plugin }

  it "correctly merges user messages with uploads" do
    builder.push(type: :user, content: "Hello", id: "Alice", upload_ids: [1])
    builder.push(type: :user, content: "World", id: "Bob", upload_ids: [2])

    messages = builder.to_a

    # Check the structure of the merged message
    expect(messages.length).to eq(1)
    expect(messages[0][:type]).to eq(:user)

    # The content should contain the text and both uploads
    content = messages[0][:content]
    expect(content).to be_an(Array)
    expect(content[0]).to eq("Alice: Hello")
    expect(content[1]).to eq({ upload_id: 1 })
    expect(content[2]).to eq("\nBob: World")
    expect(content[3]).to eq({ upload_id: 2 })
  end

  it "should allow merging user messages" do
    builder.push(type: :user, content: "Hello", id: "Alice")
    builder.push(type: :user, content: "World", id: "Bob")

    expect(builder.to_a).to eq([{ type: :user, content: "Alice: Hello\nBob: World" }])
  end

  it "should allow adding uploads" do
    builder.push(type: :user, content: "Hello", name: "Alice", upload_ids: [1, 2])

    expect(builder.to_a).to eq(
      [{ type: :user, content: ["Hello", { upload_id: 1 }, { upload_id: 2 }], name: "Alice" }],
    )
  end

  it "should support function calls" do
    builder.push(type: :user, content: "Echo 123 please", name: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :tool, content: "123", name: "echo", id: 1)
    builder.push(type: :user, content: "Hello", name: "Alice")
    expected = [
      { type: :user, content: "Echo 123 please", name: "Alice" },
      { type: :tool_call, content: "echo(123)", name: "echo", id: "1" },
      { type: :tool, content: "123", name: "echo", id: "1" },
      { type: :user, content: "Hello", name: "Alice" },
    ]
    expect(builder.to_a).to eq(expected)
  end

  it "should drop a tool call if it is not followed by tool" do
    builder.push(type: :user, content: "Echo 123 please", id: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :user, content: "OK", id: "James")

    expected = [{ type: :user, content: "Alice: Echo 123 please\nJames: OK" }]
    expect(builder.to_a).to eq(expected)
  end

  it "should format messages for topic style" do
    # Create a topic with tags
    topic = Fabricate(:topic, title: "This is an Example Topic")

    # Add tags to the topic
    topic.tags = [Fabricate(:tag, name: "tag1"), Fabricate(:tag, name: "tag2")]
    topic.save!

    builder.topic = topic
    builder.push(type: :user, content: "I like frogs", id: "Bob")
    builder.push(type: :user, content: "How do I solve this?", id: "Alice")

    result = builder.to_a(style: :topic)

    content = result[0][:content]

    expect(content).to include("This is an Example Topic")
    expect(content).to include("tag1")
    expect(content).to include("tag2")
    expect(content).to include("Bob: I like frogs")
    expect(content).to include("Alice")
    expect(content).to include("How do I solve this")
  end

  describe "chat context posts in direct messages" do
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, bot_user]) }
    fab!(:dm_message) do
      Fabricate(
        :chat_message,
        chat_channel: dm_channel,
        user: user,
        message: "I have a question about the topic",
      )
    end

    fab!(:topic) { Fabricate(:topic, title: "Important topic for context") }
    fab!(:post1) { Fabricate(:post, topic: topic, user: other_user, raw: "This is the first post") }
    fab!(:post2) { Fabricate(:post, topic: topic, user: user, raw: "And here's a follow-up") }

    it "correctly includes topic posts as context in direct message channels" do
      context =
        described_class.messages_from_chat(
          dm_message,
          channel: dm_channel,
          context_post_ids: [post1.id, post2.id],
          max_messages: 10,
          include_uploads: false,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      expect(context.length).to eq(1)
      content = context.first[:content]

      # First part should contain the context intro
      expect(content).to include("You are replying inside a Discourse chat")
      expect(content).to include(
        "This chat is in the context of the Discourse topic 'Important topic for context'",
      )
      expect(content).to include(post1.username)
      expect(content).to include("This is the first post")
      expect(content).to include(post2.username)
      expect(content).to include("And here's a follow-up")

      # Last part should have the user's message
      expect(content).to include("I have a question about the topic")
    end

    it "includes uploads from context posts when include_uploads is true" do
      upload = Fabricate(:upload, user: user)
      UploadReference.create!(target: post1, upload: upload)

      context =
        described_class.messages_from_chat(
          dm_message,
          channel: dm_channel,
          context_post_ids: [post1.id],
          max_messages: 10,
          include_uploads: true,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # Verify the upload reference is included
      upload_hashes = context.first[:content].select { |item| item.is_a?(Hash) && item[:upload_id] }
      expect(upload_hashes).to be_present
      expect(upload_hashes.first[:upload_id]).to eq(upload.id)
    end
  end

  describe ".messages_from_chat" do
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, bot_user]) }
    fab!(:dm_message1) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: user, message: "Hello bot")
    end
    fab!(:dm_message2) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: bot_user, message: "Hello human")
    end
    fab!(:dm_message3) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: user, message: "How are you?")
    end

    fab!(:public_channel) { Fabricate(:category_channel) }
    fab!(:public_message1) do
      Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Hello everyone")
    end
    fab!(:public_message2) do
      Fabricate(:chat_message, chat_channel: public_channel, user: bot_user, message: "Hi there")
    end

    fab!(:thread_original) do
      Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Thread starter")
    end
    fab!(:thread) do
      Fabricate(:chat_thread, channel: public_channel, original_message: thread_original)
    end
    fab!(:thread_reply1) do
      Fabricate(
        :chat_message,
        chat_channel: public_channel,
        user: other_user,
        message: "Thread reply",
        thread: thread,
      )
    end

    fab!(:upload) { Fabricate(:upload, user: user) }
    fab!(:message_with_upload) do
      Fabricate(
        :chat_message,
        chat_channel: dm_channel,
        user: user,
        message: "Check this image",
        upload_ids: [upload.id],
      )
    end

    it "processes messages from direct message channels" do
      context =
        described_class.messages_from_chat(
          dm_message3,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: false,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # this is all we got cause it is assuming threading
      expect(context).to eq([{ type: :user, content: "How are you?", id: user.username }])
    end

    it "includes uploads when include_uploads is true" do
      message_with_upload.reload
      expect(message_with_upload.uploads).to include(upload)

      context =
        described_class.messages_from_chat(
          message_with_upload,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: true,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # Find the message with upload
      message =
        context.find do |m|
          m[:content] ==
            ["Check this image -- uploaded(#{upload.short_url})", { upload_id: upload.id }]
        end
      expect(message).to be_present
    end

    it "doesn't include uploads when include_uploads is false" do
      # Make sure the upload is associated with the message
      message_with_upload.reload
      expect(message_with_upload.uploads).to include(upload)

      context =
        described_class.messages_from_chat(
          message_with_upload,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: false,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # Find the message with upload
      message =
        context.find { |m| m[:content] == "Check this image -- uploaded(#{upload.short_url})" }
      expect(message).to be_present
      expect(message[:upload_ids]).to be_nil
    end

    it "properly handles uploads in public channels with multiple users" do
      _first_message =
        Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "First message")

      _message_with_upload =
        Fabricate(
          :chat_message,
          chat_channel: public_channel,
          user: other_user,
          message: "Message with image",
          upload_ids: [upload.id],
        )

      last_message =
        Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Final message")

      context =
        described_class.messages_from_chat(
          last_message,
          channel: public_channel,
          context_post_ids: nil,
          max_messages: 3,
          include_uploads: true,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      expect(context.length).to eq(1)
      content = context.first[:content]

      expect(content.length).to eq(3)
      expect(content[0]).to include("First message")
      expect(content[0]).to include("Message with image")
      expect(content[1]).to include({ upload_id: upload.id })
      expect(content[2]).to include("Final message")
    end
  end

  describe "upload limits in messages_from_chat" do
    fab!(:test_channel) { Fabricate(:category_channel) }
    fab!(:test_user) { Fabricate(:user) }

    # Create MAX_CHAT_UPLOADS + 1 uploads
    fab!(:uploads) do
      (described_class::MAX_CHAT_UPLOADS + 1).times.map do |i|
        Fabricate(:upload, user: test_user, original_filename: "image#{i}.png", extension: "png")
      end
    end

    # Create MAX_CHAT_UPLOADS + 1 messages with those uploads
    fab!(:messages_with_uploads) do
      uploads.map do |upload|
        Fabricate(
          :chat_message,
          chat_channel: test_channel,
          user: test_user,
          message: "Message with upload #{upload.id}",
        ).tap do |msg|
          UploadReference.create!(target: msg, upload: upload)
          msg.update!(upload_ids: [upload.id])
        end
      end
    end

    let(:max_uploads) { described_class::MAX_CHAT_UPLOADS }

    it "limits uploads to MAX_CHAT_UPLOADS in the final result" do
      last_message = messages_with_uploads.last

      # Make sure uploads are properly associated
      messages_with_uploads.each_with_index do |msg, i|
        expect(msg.uploads.first.id).to eq(uploads[i].id)
      end

      context =
        described_class.messages_from_chat(
          last_message,
          channel: test_channel,
          context_post_ids: nil,
          max_messages: messages_with_uploads.size,
          include_uploads: true,
          bot_user_ids: [],
          instruction_message: nil,
        )

      # We should have one message containing all message content
      expect(context.length).to eq(1)
      content = context.first[:content]

      # Count the upload hashes in the content
      upload_hashes = content.select { |item| item.is_a?(Hash) && item[:upload_id] }

      # Should have exactly MAX_CHAT_UPLOADS upload references
      expect(upload_hashes.size).to eq(max_uploads)

      # The most recent uploads should be preserved (not the oldest)
      expected_upload_ids = uploads.last(max_uploads).map(&:id)
      actual_upload_ids = upload_hashes.map { |h| h[:upload_id] }
      expect(actual_upload_ids).to match_array(expected_upload_ids)
    end
  end

  describe ".messages_from_post" do
    fab!(:pm) do
      Fabricate(
        :private_message_topic,
        title: "This is my special PM",
        user: user,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user),
          Fabricate.build(:topic_allowed_user, user: bot_user),
        ],
      )
    end
    fab!(:first_post) do
      Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "This is a reply by the user")
    end
    fab!(:second_post) do
      Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "This is a bot reply")
    end
    fab!(:third_post) do
      Fabricate(
        :post,
        topic: pm,
        user: user,
        post_number: 3,
        raw: "This is a second reply by the user",
      )
    end

    it "provides rich context for for style topic messages" do
      freeze_time

      user.update!(trust_level: 2, created_at: 1.year.ago)
      admin.update!(trust_level: 4, created_at: 1.month.ago)
      user.user_stat.update!(post_count: 10, days_visited: 50)

      reply_to_first_post =
        Fabricate(
          :post,
          topic: pm,
          user: admin,
          reply_to_post_number: first_post.post_number,
          raw: "This is a reply to the first post",
        )

      context =
        described_class.messages_from_post(
          reply_to_first_post,
          style: :topic,
          max_posts: 10,
          bot_usernames: [bot_user.username],
          include_uploads: false,
        )

      expect(context.length).to eq(1)
      content = context[0][:content]

      expect(content).to include(user.name)
      expect(content).to include("Trust level 2")
      expect(content).to include("account age: 1 year")

      # I am mixed on asserting everything cause the test
      # will be brittle, but open to changing this
    end

    it "handles uploads correctly in topic style messages (and times)" do
      freeze_time 1.month.ago

      # Use Discourse's upload format in the post raw content
      upload_markdown = "![test|658x372](#{image_upload1.short_url})"

      post_with_upload =
        Fabricate(
          :post,
          topic: pm,
          user: admin,
          raw: "This is the original #{upload_markdown} I just added",
        )

      UploadReference.create!(target: post_with_upload, upload: image_upload1)

      upload2_markdown = "![test|658x372](#{image_upload2.short_url})"

      freeze_time 1.month.from_now

      post2_with_upload =
        Fabricate(
          :post,
          topic: pm,
          user: admin,
          raw: "This post has a different image #{upload2_markdown} I just added",
        )

      UploadReference.create!(target: post2_with_upload, upload: image_upload2)

      messages =
        described_class.messages_from_post(
          post2_with_upload,
          style: :topic,
          max_posts: 3,
          bot_usernames: [bot_user.username],
          include_uploads: true,
        )

      # this is not quite ideal yet, images are attached at the end of the post
      # long term we may want to extract them out using a regex and create N parts
      # so people can talk about multiple images in a single post
      # this is the initial ground work though

      expect(messages.length).to eq(1)
      content = messages[0][:content]

      # first part
      # first image
      # second part
      # second image
      expect(content.length).to eq(4)
      expect(content[0]).to include("This is the original")
      expect(content[0]).to include("(1 month ago)")
      expect(content[1]).to eq({ upload_id: image_upload1.id })
      expect(content[2]).to include("different image")
      expect(content[3]).to eq({ upload_id: image_upload2.id })
    end

    context "with limited context" do
      it "respects max_context_posts" do
        context =
          described_class.messages_from_post(
            third_post,
            max_posts: 1,
            bot_usernames: [bot_user.username],
            include_uploads: false,
          )

        expect(context).to contain_exactly(
          *[{ type: :user, id: user.username, content: third_post.raw }],
        )
      end
    end

    it "includes previous posts ordered by post_number" do
      context =
        described_class.messages_from_post(
          third_post,
          max_posts: 10,
          bot_usernames: [bot_user.username],
          include_uploads: false,
        )

      expect(context).to eq(
        [
          { type: :user, content: "This is a reply by the user", id: user.username },
          { type: :model, content: "This is a bot reply" },
          { type: :user, content: "This is a second reply by the user", id: user.username },
        ],
      )
    end

    it "handles uploads correctly in topic style messages (and times)" do
      freeze_time 1.month.ago

      # Use Discourse's upload format in the post raw content
      upload_markdown = "![test1|658x372](#{image_upload1.short_url})"

      post1 =
        Fabricate(
          :post,
          topic: pm,
          user: admin,
          raw: "This is the original #{upload_markdown} I just added",
        )

      UploadReference.create!(target: post1, upload: image_upload1)

      long_title = "A" * 40
      upload2_markdown = "![#{long_title}|658x372](#{image_upload2.short_url})"

      freeze_time 1.month.from_now

      post2_with_upload =
        Fabricate(
          :post,
          topic: pm,
          user: admin,
          raw: "This post has a different image #{upload2_markdown} I just added",
        )

      UploadReference.create!(target: post2_with_upload, upload: image_upload2)

      messages =
        described_class.messages_from_post(
          post2_with_upload,
          style: :topic,
          max_posts: 3,
          bot_usernames: [bot_user.username],
          include_uploads: true,
        )

      expect(messages.length).to eq(1)
      content = messages[0][:content]

      upload_hashes = content.select { |c| c.is_a?(Hash) }
      expect(upload_hashes).to include(
        { upload_id: image_upload1.id },
        { upload_id: image_upload2.id },
      )

      text = content.select { |c| c.is_a?(String) }.join(" ")

      expect(text).to include("This is the original")
      expect(text).to include("(1 month ago)")
      expect(text).to include("#{upload_markdown}")
      expect(text).to include("#{upload2_markdown}")
    end

    it "only include regular posts" do
      first_post.update!(post_type: Post.types[:whisper])

      context =
        described_class.messages_from_post(
          third_post,
          max_posts: 10,
          bot_usernames: [bot_user.username],
          include_uploads: false,
        )

      # skips leading model reply which makes no sense cause first post was whisper
      expect(context).to eq(
        [{ type: :user, content: "This is a second reply by the user", id: user.username }],
      )
    end

    context "with custom prompts" do
      it "When post custom prompt is present, we use that instead of the post content" do
        custom_prompt = [
          [
            { name: "time", arguments: { name: "time", timezone: "Buenos Aires" } }.to_json,
            "time",
            "tool_call",
          ],
          [
            { args: { timezone: "Buenos Aires" }, time: "2023-12-14 17:24:00 -0300" }.to_json,
            "time",
            "tool",
          ],
          ["I replied to the time command", bot_user.username],
        ]

        PostCustomPrompt.create!(post: second_post, custom_prompt: custom_prompt)

        context =
          described_class.messages_from_post(
            third_post,
            max_posts: 10,
            bot_usernames: [bot_user.username],
            include_uploads: false,
          )

        expect(context).to eq(
          [
            { type: :user, content: "This is a reply by the user", id: user.username },
            { type: :tool_call, content: custom_prompt.first.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.second.first },
            { type: :model, content: custom_prompt.third.first },
            { type: :user, content: "This is a second reply by the user", id: user.username },
          ],
        )
      end
    end
  end
end
