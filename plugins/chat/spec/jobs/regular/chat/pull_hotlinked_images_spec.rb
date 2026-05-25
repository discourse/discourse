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

    it "downloads an external image and rewrites cooked + raw" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      message.reload
      upload = Upload.last
      expect(message.message).to include(upload.short_url)
      expect(message.cooked).to include(upload.url)
      expect(message.cooked).not_to include(image_url)
      expect(message.upload_references.pluck(:upload_id)).to include(upload.id)
    end

    it "re-broadcasts the processed message after rewriting" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")

      Chat::Publisher.expects(:publish_processed!).with(instance_of(Chat::Message)).once
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

      # base_url is a string-prefix of attacker_url but the hostname is different.
      # The job should treat this as external and download it.
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

    it "aborts cleanly when the cooked content changed since we read it" do
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

      # Simulate a concurrent edit by mutating cooked in the DB during the download
      # call, after the job has already read the original cooked into memory.
      FileHelper
        .stubs(:download)
        .with do |_src, *|
          ::Chat::Message.where(id: message.id).update_all(cooked: "<p>raced</p>")
          true
        end
        .returns(tempfile)

      Chat::Publisher.expects(:publish_processed!).never

      described_class.new.execute(chat_message_id: message.id)

      message.reload
      expect(message.cooked).to eq("<p>raced</p>")
      expect(message.message).to eq(original_raw)
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
      message = fabricate_chat_message("hello world")
      blocked_cooked =
        "<p>hello <img #{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}=\"#{image_url}\"></p>"
      message.update_columns(cooked: blocked_cooked)

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      upload = Upload.last
      expect(message.reload.cooked).to include(upload.url)
      expect(message.cooked).not_to include(PrettyText::BLOCKED_HOTLINKED_SRC_ATTR)
    end
  end
end
