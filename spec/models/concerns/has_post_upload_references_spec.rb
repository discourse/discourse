# frozen_string_literal: true

RSpec.describe HasPostUploadReferences do
  fab!(:upload1, :upload)
  fab!(:upload2, :upload)
  fab!(:video_upload) { Fabricate(:upload, extension: "mp4") }

  shared_examples "has upload references" do
    let(:base_url) { "#{Discourse.base_url_no_prefix}#{Discourse.base_path}" }
    let(:image_url) { "#{base_url}#{upload1.url}" }
    let(:image_url_2) { "#{base_url}#{upload2.url}" }
    let(:video_url) { "#{base_url}#{video_upload.url}" }

    let(:raw_with_uploads) { <<~RAW }
      ![image](#{image_url})
      ![image2](#{image_url_2})
      <video width="100%" height="100%" controls>
        <source src="#{video_url}">
        <a href="#{video_url}">#{video_url}</a>
      </video>
      RAW

    let(:cooked_with_uploads) { PrettyText.cook(raw_with_uploads) }

    describe "#link_post_uploads" do
      it "finds all the uploads in the content" do
        subject.link_post_uploads

        expect(UploadReference.where(target: subject).pluck(:upload_id)).to contain_exactly(
          upload1.id,
          upload2.id,
          video_upload.id,
        )
      end

      it "uses the correct target_type for upload references" do
        subject.link_post_uploads

        upload_ref = UploadReference.find_by(target: subject, upload_id: upload1.id)
        expect(upload_ref.target_type).to eq(subject.class.name)
        expect(upload_ref.target_id).to eq(subject.id)
      end

      it "cleans up the reverse index for the current target" do
        subject.link_post_uploads
        original_ids = subject.upload_references.pluck(:id)

        subject.link_post_uploads

        expect(subject.reload.upload_references.pluck(:id)).to_not eq(original_ids)
        expect(UploadReference.where(id: original_ids).exists?).to eq(false)
      end

      it "works with fragments" do
        fragments = Nokogiri::HTML5.fragment(cooked_with_uploads)
        subject.link_post_uploads(fragments: fragments)

        expect(UploadReference.where(target: subject).pluck(:upload_id)).to contain_exactly(
          upload1.id,
          upload2.id,
          video_upload.id,
        )
      end

      context "when video thumbnails are enabled" do
        fab!(:thumbnail_upload, :image_upload)

        before do
          SiteSetting.video_thumbnails_enabled = true
          thumbnail_upload.update!(original_filename: "#{video_upload.sha1}.png")
        end

        it "links video thumbnails" do
          subject.link_post_uploads

          expect(UploadReference.where(target: subject).pluck(:upload_id)).to include(
            thumbnail_upload.id,
          )
        end
      end

      context "when secure uploads is enabled" do
        before do
          setup_s3
          SiteSetting.authorized_extensions = "pdf|png|jpg|csv|mp4"
          SiteSetting.secure_uploads = true
        end

        it "sets the access_control_post_id on uploads that don't already have the value set" do
          other_target = create_target_with_different_access_control_id
          upload2.update(access_control_post_id: other_target.id)

          FileStore::S3Store.any_instance.stubs(:has_been_uploaded?).returns(true)

          subject.link_post_uploads

          upload1.reload
          upload2.reload
          expect(upload1.access_control_post_id).to eq(expected_access_control_post_id)
          expect(upload2.access_control_post_id).not_to eq(expected_access_control_post_id)
          expect(upload2.access_control_post_id).to eq(other_target.id)
        end

        context "for custom emoji" do
          before { CustomEmoji.create(name: "meme", upload: upload1) }

          it "never sets an access control post because they should not be secure" do
            subject.link_post_uploads
            expect(upload1.reload.access_control_post_id).to eq(nil)
          end
        end
      end
    end

    describe "#each_upload_url" do
      let(:raw_with_upload) { "![image](#{image_url})" }
      let(:cooked_with_upload) { PrettyText.cook(raw_with_upload) }

      before { subject.update!(raw: raw_with_upload, cooked: cooked_with_upload) }

      it "yields upload URLs from the cooked HTML" do
        urls = []
        subject.each_upload_url { |url, _src, _sha1| urls << url }

        expect(urls.length).to eq(1)
        expect(urls.first).to include(upload1.sha1)
      end

      it "yields the sha1 when available" do
        sha1s = []
        subject.each_upload_url { |_url, _src, sha1| sha1s << sha1 }

        expect(sha1s).to include(upload1.sha1)
      end

      it "works with fragments" do
        fragments = Nokogiri::HTML5.fragment(cooked_with_upload)
        urls = []
        subject.each_upload_url(fragments: fragments) { |url, _src, _sha1| urls << url }

        expect(urls.length).to eq(1)
        expect(urls.first).to include(upload1.sha1)
      end

      it "handles short URLs" do
        short_url_raw = "![image](#{upload1.short_url})"
        short_url_cooked = PrettyText.cook(short_url_raw)
        subject.update!(raw: short_url_raw, cooked: short_url_cooked)

        sha1s = []
        subject.each_upload_url { |_url, _src, sha1| sha1s << sha1 }

        expect(sha1s).to include(upload1.sha1)
      end

      it "handles upload:// protocol URLs" do
        upload_protocol_raw = "![image](upload://#{upload1.base62_sha1}.png)"
        upload_protocol_cooked = PrettyText.cook(upload_protocol_raw)
        subject.update!(raw: upload_protocol_raw, cooked: upload_protocol_cooked)

        sha1s = []
        subject.each_upload_url { |_url, _src, sha1| sha1s << sha1 }

        expect(sha1s).to include(upload1.sha1)
      end
    end
  end

  context "with Post" do
    fab!(:user, :admin)

    let(:post) do
      Fabricate(
        :post,
        raw: raw_with_uploads,
        cooked: cooked_with_uploads,
        user: user,
        skip_validation: true,
      )
    end
    let(:subject) { post }
    let(:expected_access_control_post_id) { post.id }

    def create_target_with_different_access_control_id
      Fabricate(:post)
    end

    include_examples "has upload references"

    context "when handling video thumbnails" do
      fab!(:thumbnail_upload, :image_upload)

      before do
        SiteSetting.video_thumbnails_enabled = true
        thumbnail_upload.update!(original_filename: "#{video_upload.sha1}.png")
      end

      it "sets topic image_upload_id for first posts" do
        first_post =
          Fabricate(
            :post,
            raw: raw_with_uploads,
            cooked: cooked_with_uploads,
            skip_validation: true,
          )
        first_post.link_post_uploads

        expect(first_post.topic.reload.image_upload_id).to eq(thumbnail_upload.id)
      end

      it "does not set topic image_upload_id for non-first posts" do
        topic = Fabricate(:topic)
        Fabricate(:post, topic: topic, skip_validation: true)
        second_post =
          Fabricate(
            :post,
            topic: topic,
            raw: raw_with_uploads,
            cooked: cooked_with_uploads,
            skip_validation: true,
          )

        second_post.link_post_uploads

        expect(topic.reload.image_upload_id).to be_nil
      end
    end
  end

  context "with PostLocalization" do
    fab!(:post)

    let(:localization) do
      Fabricate(:post_localization, post: post, raw: raw_with_uploads, cooked: cooked_with_uploads)
    end

    let(:subject) { localization }
    let(:expected_access_control_post_id) { post.id }

    def create_target_with_different_access_control_id
      Fabricate(:post)
    end

    include_examples "has upload references"

    it "uses the parent post's ID for access control" do
      setup_s3
      SiteSetting.authorized_extensions = "pdf|png|jpg|csv|mp4"
      SiteSetting.secure_uploads = true

      FileStore::S3Store.any_instance.stubs(:has_been_uploaded?).returns(true)

      localization.link_post_uploads

      upload1.reload
      expect(upload1.access_control_post_id).to eq(post.id)
    end
  end
end
