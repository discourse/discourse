# frozen_string_literal: true

describe Jobs::Chat::PullHotlinkedImages do
  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.gif" }
  let(:broken_image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat3.png" }
  let(:gif) do
    Base64.decode64(
      "R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==",
    )
  end

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:chat_channel)

  before do
    Jobs.run_immediately!

    stub_request(:get, image_url).to_return(body: gif, headers: { "Content-Type" => "image/gif" })
    stub_request(:get, broken_image_url).to_return(status: 404)

    SiteSetting.download_remote_images_to_local = true
    SiteSetting.max_image_size_kb = 2
    SiteSetting.download_remote_images_threshold = 0
  end

  def fabricate_chat_message(raw)
    Fabricate(:chat_message, chat_channel: chat_channel, user: user, message: raw)
  end

  describe "#execute" do
    it "raises when chat_message_id is missing" do
      expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
    end

    it "does nothing if the message no longer exists" do
      expect { described_class.new.execute(chat_message_id: -1) }.not_to change { Upload.count }
    end

    it "does nothing when the message has no cooked content" do
      message = fabricate_chat_message("placeholder body")
      message.update_columns(cooked: nil)

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
    end

    it "does nothing when the message body is blank (system/webhook messages)" do
      message = fabricate_chat_message("placeholder")
      message.update_columns(message: "", cooked: "<p><img src=\"#{image_url}\"></p>")

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.cooked).to include(image_url)
    end

    it "downloads an external image and rewrites raw + cooked (via ProcessMessage)" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      message.reload
      upload = Upload.last
      expect(message.message).to include(upload.short_url)
      expect(message.cooked).to include("data-base62-sha1=\"#{upload.base62_sha1}\"")
      expect(message.cooked).not_to include(image_url)
      expect(message.upload_references.pluck(:upload_id)).to include(upload.id)
    end

    it "records a hotlinked media row per attempted URL and does not retry terminal failures" do
      raw = "![broken](#{broken_image_url})"
      message = fabricate_chat_message(raw)

      described_class.new.execute(chat_message_id: message.id)

      record = message.reload.hotlinked_media.first
      expect(record).to be_present
      expect(record.status).to eq("download_failed")

      # Second run does not re-attempt the download — the record is terminal.
      FileHelper.expects(:download).never
      described_class.new.execute(chat_message_id: message.id)

      expect(message.hotlinked_media.count).to eq(1)
    end

    it "classifies an oversize image as :too_large (not :download_failed)" do
      huge = "a" * (SiteSetting.max_image_size_kb * 1024 * 2)
      stub_request(:get, image_url).to_return(
        body: huge,
        headers: {
          "Content-Type" => "image/gif",
        },
      )
      message = fabricate_chat_message("![big](#{image_url})")

      described_class.new.execute(chat_message_id: message.id)

      record = message.reload.hotlinked_media.first
      expect(record).to be_present
      expect(record.status).to eq("too_large")
    end

    it "rewrites a re-introduced URL using the cached hotlinked media row and refreshes cooked" do
      stub_image_size
      first = fabricate_chat_message("first: ![](#{image_url})")
      described_class.new.execute(chat_message_id: first.id)
      upload = Upload.last

      # User edits the message to re-introduce the same external URL.
      first.update_columns(
        message: "again: ![](#{image_url})",
        cooked: "<p><img src=\"#{image_url}\"></p>",
      )

      expect { described_class.new.execute(chat_message_id: first.id) }.not_to change {
        Upload.count
      }
      first.reload
      expect(first.message).to include(upload.short_url)
      # ProcessMessage re-cooks even though nothing new was downloaded this run.
      expect(first.cooked).to include("data-base62-sha1=\"#{upload.base62_sha1}\"")
      expect(first.cooked).not_to include(image_url)
    end

    it "does not leak an orphan upload when the rewrite can't reference the image" do
      stub_image_size
      message = fabricate_chat_message("plain text, no markdown image")
      # cooked has an external <img> with no corresponding markdown in raw.
      message.update_columns(cooked: "<p>plain text <img src=\"#{image_url}\"></p>")

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      # A terminal tracking row remains so we don't re-download on every edit,
      # but the unreferenced upload was cleaned up.
      record = message.reload.hotlinked_media.first
      expect(record).to be_present
      expect(record.upload).to be_nil
      expect(message.message).to eq("plain text, no markdown image")
    end

    it "does not enqueue ProcessMessage when every download fails" do
      message = fabricate_chat_message("![broken](#{broken_image_url})")

      ::Jobs.expects(:enqueue).with(::Jobs::Chat::ProcessMessage, anything).never

      described_class.new.execute(chat_message_id: message.id)
    end

    it "re-enqueues ProcessMessage with skip_pull_hotlinked_images on successful rewrite" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")

      ::Jobs
        .expects(:enqueue)
        .with(
          ::Jobs::Chat::ProcessMessage,
          has_entries(chat_message_id: message.id, skip_pull_hotlinked_images: true),
        )
        .at_least_once

      described_class.new.execute(chat_message_id: message.id)
    end

    it "is a no-op when the setting is disabled" do
      SiteSetting.download_remote_images_to_local = false
      raw = "![longcat](#{image_url})"
      message = fabricate_chat_message(raw)

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.message).to eq(raw)
    end

    it "skips emoji imgs" do
      message = fabricate_chat_message(":heart: from #{user.username}")

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
    end

    it "skips avatar imgs" do
      message = fabricate_chat_message("hello world")
      message.update_columns(cooked: "<p>hello <img class=\"avatar\" src=\"#{image_url}\"></p>")

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
    end

    it "skips local /uploads URLs" do
      raw = "![local](/uploads/default/local.png)"
      message = fabricate_chat_message(raw)

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.message).to eq(raw)
    end

    it "skips local URLs even if the host string is a prefix of the src" do
      attacker_url = "#{Discourse.base_url}.attacker.example/foo.png"
      stub_request(:get, attacker_url).to_return(
        body: gif,
        headers: {
          "Content-Type" => "image/gif",
        },
      )
      stub_image_size
      message = fabricate_chat_message("![](#{attacker_url})")

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)
    end

    it "downloads protocol-relative URLs" do
      relative_url = "//wiki.mozilla.org/images/2/2e/Longcat1.gif"
      stub_image_size
      message = fabricate_chat_message("![](#{relative_url})")

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)
    end

    it "aborts cleanly when the message body changed since we read it" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")
      original_raw = message.message

      tempfile =
        Tempfile
          .new(%w[raced .gif])
          .tap do |f|
            f.binmode
            f.write(gif)
            f.rewind
          end

      FileHelper
        .stubs(:download)
        .with do |_src, *|
          ::Chat::Message.where(id: message.id).update_all(message: "raced edit")
          true
        end
        .returns(tempfile)

      described_class.new.execute(chat_message_id: message.id)

      expect(message.reload.message).to eq("raced edit")
      expect(original_raw).not_to eq("raced edit")
    end

    it "re-uses an existing upload when the same hotlinked URL appears in another message" do
      stub_image_size
      first = fabricate_chat_message("first: ![](#{image_url})")
      described_class.new.execute(chat_message_id: first.id)
      upload = Upload.last

      second = fabricate_chat_message("second: ![](#{image_url})")

      expect { described_class.new.execute(chat_message_id: second.id) }.not_to change {
        Upload.count
      }
      expect(second.reload.message).to include(upload.short_url)
    end

    it "leaves the message untouched when the download fails" do
      raw = "![broken](#{broken_image_url})"
      message = fabricate_chat_message(raw)
      original_cooked = message.cooked

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.cooked).to eq(original_cooked)
      expect(message.message).to eq(raw)
    end

    it "downloads images that block_hotlinked_media moved to a data attribute" do
      stub_image_size
      message = fabricate_chat_message("![](#{image_url})")
      blocked_cooked = "<p><img #{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}=\"#{image_url}\"></p>"
      message.update_columns(cooked: blocked_cooked)

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      upload = Upload.last
      expect(message.reload.cooked).to include(upload.url)
      expect(message.cooked).not_to include(PrettyText::BLOCKED_HOTLINKED_SRC_ATTR)
    end

    it "stores tracking rows scoped to the chat message" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")

      described_class.new.execute(chat_message_id: message.id)

      record = Chat::MessageHotlinkedMedia.find_by(chat_message_id: message.id)
      expect(record).to be_present
      expect(record.status).to eq("downloaded")
      expect(message.hotlinked_media).to include(record)
    end

    it "destroys tracking rows when the message is destroyed" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")
      described_class.new.execute(chat_message_id: message.id)
      expect(message.reload.hotlinked_media.count).to eq(1)

      expect { message.destroy! }.to change { Chat::MessageHotlinkedMedia.count }.by(-1)
    end
  end
end
