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

    it "does nothing when the message cannot be recooked" do
      missing_cooked = fabricate_chat_message("placeholder body")
      missing_cooked.update_columns(cooked: nil)
      hand_written = fabricate_chat_message("placeholder")
      hand_written.update_columns(message: "", cooked: "<p><img src=\"#{image_url}\"></p>")

      expect {
        described_class.new.execute(chat_message_id: missing_cooked.id)
        described_class.new.execute(chat_message_id: hand_written.id)
      }.not_to change { Upload.count }
      expect(hand_written.reload.cooked).to include(image_url)
    end

    it "downloads an external image and localizes it in cooked, leaving raw untouched" do
      stub_image_size
      raw = "![longcat](#{image_url})"
      message = fabricate_chat_message(raw)

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      message.reload
      upload = Upload.last
      expect(message.message).to eq(raw)
      expect(message.cooked).to include(upload.url)
      expect(message.cooked).to include("data-base62-sha1=\"#{upload.base62_sha1}\"")
      expect(message.cooked).not_to include(image_url)
      expect(message.upload_references).to be_empty
    end

    it "records terminal failures without changing the message or retrying" do
      raw = "![broken](#{broken_image_url})"
      message = fabricate_chat_message(raw)
      original_cooked = message.cooked

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }

      record = message.reload.hotlinked_media.first
      expect(record).to be_present
      expect(record.status).to eq("download_failed")
      expect(message.cooked).to eq(original_cooked)
      expect(message.message).to eq(raw)

      described_class.new.execute(chat_message_id: message.id)

      expect(message.hotlinked_media.count).to eq(1)
      expect(WebMock).to have_requested(:get, broken_image_url).once
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

    it "localizes a re-introduced URL from the cached hotlinked media row without re-downloading" do
      stub_image_size
      first = fabricate_chat_message("first: ![](#{image_url})")
      described_class.new.execute(chat_message_id: first.id)
      upload = Upload.last

      first.update_columns(
        message: "again: ![](#{image_url})",
        cooked: "<p><img src=\"#{image_url}\"></p>",
      )

      expect { described_class.new.execute(chat_message_id: first.id) }.not_to change {
        Upload.count
      }
      first.reload
      expect(first.cooked).to include("data-base62-sha1=\"#{upload.base62_sha1}\"")
      expect(first.cooked).not_to include(image_url)
    end

    it "localizes an image that only exists in cooked, such as a onebox thumbnail" do
      stub_image_size
      message = fabricate_chat_message("https://example.com/interesting-page")
      onebox_cooked =
        "<aside class=\"onebox\"><img src=\"#{image_url}\" width=\"100\" height=\"100\"></aside>"
      Chat::Message.stubs(:cook).returns(onebox_cooked)
      message.update_columns(cooked: onebox_cooked)

      expect { described_class.new.execute(chat_message_id: message.id) }.to change {
        Upload.count
      }.by(1)

      message.reload
      upload = Upload.last
      expect(message.message).to eq("https://example.com/interesting-page")
      expect(message.cooked).to include(upload.url)
      expect(message.cooked).not_to include(image_url)
      expect(message.upload_references).to be_empty
    end

    it "does not destroy a pre-existing unreferenced upload the download dedups to" do
      stub_image_size
      first = fabricate_chat_message("first: ![](#{image_url})")
      described_class.new.execute(chat_message_id: first.id)
      upload = Upload.last

      first.destroy!
      expect(UploadReference.where(upload_id: upload.id)).to be_empty

      second = fabricate_chat_message("second: ![](#{image_url})")
      described_class.new.execute(chat_message_id: second.id)

      expect(Upload.exists?(upload.id)).to eq(true)
      expect(second.reload.hotlinked_media.first.upload_id).to eq(upload.id)
      expect(second.upload_references).to be_empty
    end

    it "does not re-cook when nothing was downloaded" do
      message = fabricate_chat_message("![broken](#{broken_image_url})")
      Jobs.run_later!

      expect_not_enqueued_with(job: ::Jobs::Chat::ProcessMessage) do
        described_class.new.execute(chat_message_id: message.id)
      end
    end

    it "re-cooks with the pull skipped, so processing cannot enqueue us again" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")
      Jobs.run_later!

      described_class.new.execute(chat_message_id: message.id)

      expect(
        job_enqueued?(
          job: ::Jobs::Chat::ProcessMessage,
          args: {
            chat_message_id: message.id,
            skip_pull_hotlinked_images: true,
          },
        ),
      ).to eq(true)
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

    it "is a no-op when chat uploads are disabled" do
      SiteSetting.chat_allow_uploads = false
      message = fabricate_chat_message("![longcat](#{image_url})")

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.hotlinked_media).to be_empty
      expect(WebMock).not_to have_requested(:get, image_url)
    end

    it "skips local /uploads URLs" do
      raw = "![local](/uploads/default/local.png)"
      message = fabricate_chat_message(raw)

      expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
        Upload.count
      }
      expect(message.reload.message).to eq(raw)
    end

    context "with secure upload proxy URLs" do
      before do
        setup_s3
        SiteSetting.secure_uploads = true
        stub_request(:get, /s3-upload-bucket.*amazonaws\.com/).to_return(
          body: gif,
          headers: {
            "Content-Type" => "image/gif",
          },
        )
      end

      it "does not rehost secure upload proxy URLs" do
        global_setting :allow_unsecure_chat_uploads, true
        SiteSetting.chat_allow_uploads = true

        # the multisite path is the one the local-upload check would let through
        %w[
          /secure-uploads/original/1X/1234567890abcdef1234567890abcdef12345678.png
          /secure-uploads/uploads/default/original/1X/1234567890abcdef1234567890abcdef12345678.png
        ].each do |path|
          stub_image_size
          message = fabricate_chat_message("![](#{Discourse.base_url}#{path})")

          expect { described_class.new.execute(chat_message_id: message.id) }.not_to change {
            Upload.count
          }
          expect(message.reload.hotlinked_media).to be_empty
        end
        expect(WebMock).not_to have_requested(:get, /amazonaws\.com/)
      end
    end

    it "does not treat an attacker host with the local host prefix as local" do
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

    it "destroys tracking rows when the message is destroyed" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")
      described_class.new.execute(chat_message_id: message.id)
      expect(message.reload.hotlinked_media.count).to eq(1)

      expect { message.destroy! }.to change { Chat::MessageHotlinkedMedia.count }.by(-1)
    end

    it "destroys tracking rows when the upload is destroyed" do
      stub_image_size
      message = fabricate_chat_message("![longcat](#{image_url})")
      described_class.new.execute(chat_message_id: message.id)
      upload = message.reload.hotlinked_media.first.upload

      expect { upload.destroy! }.to change { Chat::MessageHotlinkedMedia.count }.by(-1)
    end
  end
end
