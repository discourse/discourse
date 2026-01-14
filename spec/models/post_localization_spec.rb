# frozen_string_literal: true

RSpec.describe PostLocalization do
  fab!(:post)
  fab!(:upload1, :upload)
  fab!(:upload2, :upload)
  fab!(:video_upload) { Fabricate(:upload, extension: "mp4") }

  describe "associations" do
    it { is_expected.to have_many(:upload_references).dependent(:destroy) }
    it { is_expected.to have_many(:uploads).through(:upload_references) }
    it { is_expected.to belong_to(:post) }
  end

  describe "#link_post_uploads" do
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

    let(:localization) do
      Fabricate(:post_localization, post: post, raw: raw_with_uploads, cooked: cooked_with_uploads)
    end

    it "finds all the uploads in the localization" do
      localization.link_post_uploads

      expect(UploadReference.where(target: localization).pluck(:upload_id)).to contain_exactly(
        upload1.id,
        upload2.id,
        video_upload.id,
      )
    end

    it "uses the correct target_type for upload references" do
      localization.link_post_uploads

      upload_ref = UploadReference.find_by(target: localization, upload_id: upload1.id)
      expect(upload_ref.target_type).to eq("PostLocalization")
      expect(upload_ref.target_id).to eq(localization.id)
    end

    it "cleans the reverse index up for the current localization" do
      localization.link_post_uploads

      localization_uploads_ids = localization.upload_references.pluck(:id)

      localization.link_post_uploads

      expect(localization.reload.upload_references.pluck(:id)).to_not contain_exactly(
        localization_uploads_ids,
      )
    end

    it "works with fragments" do
      fragments = Nokogiri::HTML5.fragment(cooked_with_uploads)
      localization.link_post_uploads(fragments: fragments)

      expect(UploadReference.where(target: localization).pluck(:upload_id)).to contain_exactly(
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
        localization.link_post_uploads

        expect(UploadReference.where(target: localization).pluck(:upload_id)).to include(
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

      it "sets the access_control_post_id to the parent post on uploads that don't already have the value set" do
        other_post = Fabricate(:post)
        upload2.update(access_control_post_id: other_post.id)

        FileStore::S3Store.any_instance.stubs(:has_been_uploaded?).returns(true)

        localization.link_post_uploads

        upload1.reload
        upload2.reload
        expect(upload1.access_control_post_id).to eq(post.id)
        expect(upload2.access_control_post_id).not_to eq(post.id)
        expect(upload2.access_control_post_id).to eq(other_post.id)
      end

      context "for custom emoji" do
        before { CustomEmoji.create(name: "meme", upload: upload1) }

        it "never sets an access control post because they should not be secure" do
          localization.link_post_uploads
          expect(upload1.reload.access_control_post_id).to eq(nil)
        end
      end
    end
  end

  describe "#each_upload_url" do
    let(:base_url) { "#{Discourse.base_url_no_prefix}#{Discourse.base_path}" }
    let(:image_url) { "#{base_url}#{upload1.url}" }
    let(:raw_with_upload) { "![image](#{image_url})" }
    let(:cooked_with_upload) { PrettyText.cook(raw_with_upload) }

    let(:localization) do
      Fabricate(:post_localization, post: post, raw: raw_with_upload, cooked: cooked_with_upload)
    end

    it "yields upload URLs from the cooked HTML" do
      urls = []
      localization.each_upload_url { |url, _src, _sha1| urls << url }

      expect(urls.length).to eq(1)
      expect(urls.first).to include(upload1.sha1)
    end

    it "yields the sha1 when available" do
      sha1s = []
      localization.each_upload_url { |_url, _src, sha1| sha1s << sha1 }

      expect(sha1s).to include(upload1.sha1)
    end

    it "works with fragments" do
      fragments = Nokogiri::HTML5.fragment(cooked_with_upload)
      urls = []
      localization.each_upload_url(fragments: fragments) { |url, _src, _sha1| urls << url }

      expect(urls.length).to eq(1)
      expect(urls.first).to include(upload1.sha1)
    end
  end
end
