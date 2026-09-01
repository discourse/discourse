# frozen_string_literal: true

describe Jobs::Chat::ProcessMessage do
  fab!(:chat_message) { Fabricate(:chat_message, message: "https://discourse.org/team") }

  before do
    stub_request(:get, "https://discourse.org/team").to_return(
      status: 200,
      body: "<html><head><title>a</title></head></html>",
    )

    stub_request(:head, "https://discourse.org/team").to_return(status: 200)
  end

  it "updates cooked with oneboxes" do
    described_class.new.execute(chat_message_id: chat_message.id)
    expect(chat_message.reload.cooked).to eq(
      "<aside class=\"onebox allowlistedgeneric\" data-onebox-src=\"https://discourse.org/team\">\n  <header class=\"source\">\n\n      <a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">discourse.org</a>\n  </header>\n\n  <article class=\"onebox-body\">\n    \n\n<h3><a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">a</a></h3>\n\n\n\n  </article>\n\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n\n  <div style=\"clear: both\"></div>\n</aside>\n",
    )
  end

  it "preserves action formatting when processing a message" do
    action_message = Fabricate(:chat_message, message: "/me waves")

    described_class.new.execute(chat_message_id: action_message.id)

    expect(action_message.reload.cooked).to match_html(
      %(<p><em class="chat-message-action">#{action_message.user.username} waves</em></p>),
    )
  end

  context "when the cooked message changed" do
    it "publishes the update" do
      chat_message.update!(cooked: "another lovely cat")
      Chat::Publisher.expects(:publish_processed!).once
      described_class.new.execute(chat_message_id: chat_message.id)
    end
  end

  it "does not error when message is deleted" do
    chat_message.destroy
    expect { described_class.new.execute(chat_message_id: chat_message.id) }.not_to raise_exception
  end

  it "extracts links from the message" do
    described_class.new.execute(chat_message_id: chat_message.id)

    link = Chat::MessageLink.find_by(chat_message_id: chat_message.id)
    expect(link).to be_present
    expect(link.url).to eq("https://discourse.org/team")
  end

  describe "invalidate_oneboxes" do
    it "invalidates cached oneboxes and fetches fresh content" do
      # Process the message once to populate the onebox cache
      described_class.new.execute(chat_message_id: chat_message.id)
      original_cooked = chat_message.reload.cooked
      expect(original_cooked).to include("discourse.org")

      # Update the stub to return different content
      stub_request(:get, "https://discourse.org/team").to_return(
        status: 200,
        body: "<html><head><title>Updated Title</title></head></html>",
      )

      # Rebake with invalidate_oneboxes: true - this should fetch fresh content
      described_class.new.execute(chat_message_id: chat_message.id, invalidate_oneboxes: true)
      new_cooked = chat_message.reload.cooked
      expect(new_cooked).to include("Updated Title")
    end
  end

  describe "pull hotlinked images" do
    let(:image_url) { "https://example.com/img.png" }
    fab!(:hotlinked_message) do
      Fabricate(:chat_message, message: "![](https://example.com/img.png)")
    end

    it "enqueues the pull job when download_remote_images_to_local is enabled" do
      SiteSetting.download_remote_images_to_local = true

      expect_enqueued_with(
        job: Jobs::Chat::PullHotlinkedImages,
        args: {
          chat_message_id: hotlinked_message.id,
        },
      ) { described_class.new.execute(chat_message_id: hotlinked_message.id) }
    end

    # the job costs a slot, a lock and a disk check, and the overwhelming
    # majority of messages have nothing external in them
    it "does not enqueue the pull job for a message with nothing to fetch" do
      SiteSetting.download_remote_images_to_local = true

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: chat_message.id)
      end
    end

    it "does not enqueue the pull job when tracked media is localized during processing" do
      SiteSetting.download_remote_images_to_local = true
      Chat::MessageHotlinkedMedia.create!(
        chat_message: hotlinked_message,
        url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
        status: :downloaded,
        upload: Fabricate(:upload),
      )

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: hotlinked_message.id)
      end
    end

    it "does not enqueue the pull job for tracked media with a terminal failure" do
      SiteSetting.download_remote_images_to_local = true
      Chat::MessageHotlinkedMedia.create!(
        chat_message: hotlinked_message,
        url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
        status: :too_large,
      )

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: hotlinked_message.id)
      end
    end

    it "enqueues the pull job for a local upload URL that resolves to nothing" do
      SiteSetting.download_remote_images_to_local = true
      orphan_url = "#{Discourse.base_url}/uploads/default/original/1X/#{SecureRandom.hex(20)}.png"
      message = Fabricate(:chat_message, message: "![](#{orphan_url})")

      expect_enqueued_with(
        job: Jobs::Chat::PullHotlinkedImages,
        args: {
          chat_message_id: message.id,
        },
      ) { described_class.new.execute(chat_message_id: message.id) }
    end

    it "does not enqueue the pull job for an image that is already a local upload" do
      SiteSetting.download_remote_images_to_local = true
      upload = Fabricate(:upload)
      message = Fabricate(:chat_message, message: "![](#{upload.url})")

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: message.id)
      end
    end

    it "does not enqueue the pull job when download_remote_images_to_local is disabled" do
      SiteSetting.download_remote_images_to_local = false

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: hotlinked_message.id)
      end
    end

    it "does not enqueue the pull job when chat uploads are disabled" do
      SiteSetting.download_remote_images_to_local = true
      SiteSetting.chat_allow_uploads = false

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(chat_message_id: hotlinked_message.id)
      end
    end

    # the pull job re-cooks through here, so the enqueue has to happen outside
    # our own mutex or the inline re-cook blocks on the lock we still hold
    it "does not block on its own lock when the pull job runs inline" do
      image_url = "http://wiki.mozilla.org/images/2/2e/Longcat1.gif"
      stub_request(:get, image_url).to_return(
        body:
          Base64.decode64(
            "R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==",
          ),
        headers: {
          "Content-Type" => "image/gif",
        },
      )
      stub_image_size
      Jobs.run_immediately!
      SiteSetting.download_remote_images_to_local = true
      SiteSetting.download_remote_images_threshold = 0
      message = Fabricate(:chat_message, message: "![longcat](#{image_url})")

      Timeout.timeout(10) { described_class.new.execute(chat_message_id: message.id) }

      expect(message.reload.cooked).not_to include(image_url)
    end

    # the pull job re-cooks through here, so honouring the flag is what stops
    # the two jobs enqueueing each other
    it "does not enqueue the pull job when it was the pull job that asked for the re-cook" do
      SiteSetting.download_remote_images_to_local = true

      expect_not_enqueued_with(job: Jobs::Chat::PullHotlinkedImages) do
        described_class.new.execute(
          chat_message_id: hotlinked_message.id,
          skip_pull_hotlinked_images: true,
        )
      end
    end
  end

  it "removes hotlinked media that is no longer present after re-cooking" do
    image_url = "https://example.com/old.png"
    message = Fabricate(:chat_message, message: "![](#{image_url})")
    record =
      Chat::MessageHotlinkedMedia.create!(
        chat_message: message,
        url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
        status: :downloaded,
        upload: Fabricate(:upload),
      )
    message.update_columns(message: "no image")

    expect { described_class.new.execute(chat_message_id: message.id) }.to change {
      Chat::MessageHotlinkedMedia.exists?(record.id)
    }.from(true).to(false)
  end

  # the pull job inserts rows while we cook, so sweeping everything the cook did
  # not use would carry away a row that did not exist yet when it read them
  it "keeps hotlinked media inserted after the cook read the tracked rows" do
    image_url = "https://example.com/late.png"
    message = Fabricate(:chat_message, message: "![](#{image_url})")
    record = nil
    insert_late_row =
      Proc.new do
        record ||=
          Chat::MessageHotlinkedMedia.create!(
            chat_message: message,
            url: Chat::MessageHotlinkedMedia.normalize_src(image_url),
            status: :downloaded,
            upload: Fabricate(:upload),
          )
      end

    DiscourseEvent.on(:chat_message_processed, &insert_late_row)
    begin
      described_class.new.execute(chat_message_id: message.id)
    ensure
      DiscourseEvent.off(:chat_message_processed, &insert_late_row)
    end

    expect(Chat::MessageHotlinkedMedia.exists?(record.id)).to eq(true)
  end

  describe "skip_notifications" do
    fab!(:user)
    fab!(:mentioned_user, :user)
    fab!(:chat_channel)
    fab!(:message_with_mention) do
      Fabricate(:chat_message, chat_channel:, user:, message: "Hey @#{mentioned_user.username}!")
    end

    before do
      chat_channel.add(user)
      chat_channel.add(mentioned_user)
    end

    it "sends notifications by default" do
      expect_enqueued_with(job: Jobs::Chat::NotifyMentioned) do
        described_class.new.execute(chat_message_id: message_with_mention.id)
      end
    end

    it "skips notifications when skip_notifications is true" do
      expect_not_enqueued_with(job: Jobs::Chat::NotifyMentioned) do
        described_class.new.execute(
          chat_message_id: message_with_mention.id,
          skip_notifications: true,
        )
      end
    end

    it "skips watching notifications when skip_notifications is true" do
      expect_not_enqueued_with(job: Jobs::Chat::NotifyWatching) do
        described_class.new.execute(
          chat_message_id: message_with_mention.id,
          skip_notifications: true,
        )
      end
    end
  end
end
