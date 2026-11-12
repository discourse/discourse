# frozen_string_literal: true

RSpec.describe LocalizedCookedPostProcessor do
  fab!(:post)
  fab!(:upload1, :upload)
  fab!(:upload2, :upload)

  let(:image_url) { upload1.short_url }
  let(:image_url_2) { upload2.short_url }

  let(:raw_with_uploads) { <<~RAW }
    これは翻訳されたコンテンツです。
    ![image](#{image_url})
    ![image2](#{image_url_2})
    RAW

  let(:cooked_with_uploads) { PrettyText.cook(raw_with_uploads) }

  let(:localization) do
    Fabricate(:post_localization, post: post, raw: raw_with_uploads, cooked: cooked_with_uploads)
  end

  let(:processor) { LocalizedCookedPostProcessor.new(localization, post) }

  describe "#post_process" do
    it "calls link_post_uploads on the localization" do
      localization.expects(:link_post_uploads).with(
        fragments: processor.instance_variable_get(:@doc),
      )
      processor.post_process
    end

    it "triggers the localized cooked post-process event", :aggregate_failures do
      events =
        DiscourseEvent.track_events(:post_process_localized_cooked) { processor.post_process }

      expect(events.size).to eq(1)
      expect(events.first[:params].first.to_html).to include(upload1.base62_sha1)
      expect(events.first[:params].second).to eq(post)
      expect(events.first[:params].third).to eq(localization)
    end

    it "creates upload references for uploads in the localization" do
      processor.post_process

      upload_ids = UploadReference.where(target: localization).pluck(:upload_id)
      expect(upload_ids).to contain_exactly(upload1.id, upload2.id)
    end

    it "uses PostLocalization as the target type for upload references" do
      processor.post_process

      upload_ref = UploadReference.find_by(target: localization, upload_id: upload1.id)
      expect(upload_ref.target_type).to eq("PostLocalization")
      expect(upload_ref.target_id).to eq(localization.id)
    end

    context "when the localization already has upload references" do
      before do
        UploadReference.create!(
          target: localization,
          upload: upload1,
          created_at: Time.zone.now,
          updated_at: Time.zone.now,
        )
      end

      it "replaces the old upload references" do
        old_ref_id = localization.upload_references.first.id

        processor.post_process

        expect(UploadReference.exists?(old_ref_id)).to eq(false)
        expect(localization.reload.upload_references.pluck(:upload_id)).to contain_exactly(
          upload1.id,
          upload2.id,
        )
      end
    end

    context "with an internal topic onebox" do
      fab!(:linked_topic) { Fabricate(:topic, title: "Sun Tzu's strategies", locale: "en") }
      fab!(:linked_post) do
        Fabricate(
          :post,
          topic: linked_topic,
          post_number: 1,
          locale: "en",
          raw: "Subdue the enemy without fighting.",
        )
      end

      let(:onebox_localization) do
        raw = linked_topic.url
        Fabricate(
          :post_localization,
          post: post,
          locale: "ja",
          raw: raw,
          cooked: PrettyText.cook(raw),
        )
      end

      before do
        SiteSetting.content_localization_enabled = true
        Fabricate(:topic_localization, topic: linked_topic, locale: "ja", title: "孫子の兵法")
        Fabricate(:post_localization, post: linked_post, locale: "ja", cooked: "<p>戦わずして勝つ</p>")
      end

      it "renders the onebox card in the localization's locale" do
        processor = LocalizedCookedPostProcessor.new(onebox_localization, post)
        processor.post_process_oneboxes

        html = processor.html
        expect(html).to include("孫子の兵法")
        expect(html).to include("戦わずして勝つ")
        expect(html).not_to include("Sun Tzu")
        expect(html).not_to include("Subdue the enemy")
      end
    end

    context "when secure uploads is enabled" do
      before do
        setup_s3
        SiteSetting.authorized_extensions = "pdf|png|jpg|csv"
        SiteSetting.secure_uploads = true
      end

      it "sets access_control_post_id to the parent post" do
        processor.post_process

        upload1.reload
        expect(upload1.access_control_post_id).to eq(post.id)
      end

      it "does not override existing access_control_post_id" do
        other_post = Fabricate(:post)
        upload1.update!(access_control_post_id: other_post.id)

        processor.post_process

        upload1.reload
        expect(upload1.access_control_post_id).to eq(other_post.id)
      end
    end
  end
end
