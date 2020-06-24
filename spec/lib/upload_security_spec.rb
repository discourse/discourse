# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadSecurity do
  let(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  let(:post_in_secure_context) { Fabricate(:post, topic: Fabricate(:topic, category: private_category)) }
  fab!(:upload) { Fabricate(:upload) }
  let(:type) { nil }
  let(:opts) { { type: type } }
  subject { described_class.new(upload, opts) }

  context "when uploading in public context" do
    describe "for a public type avatar" do
      let(:type) { 'avatar' }
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
    describe "for a public type custom_emoji" do
      let(:type) { 'custom_emoji' }
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
    describe "for a public type profile_background" do
      let(:type) { 'profile_background' }
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
    describe "for a public type avatar" do
      let(:type) { 'avatar' }
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end

    describe "for_theme" do
      before do
        upload.stubs(:for_theme).returns(true)
      end
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
    describe "for_site_setting" do
      before do
        upload.stubs(:for_site_setting).returns(true)
      end
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
    describe "for_gravatar" do
      before do
        upload.stubs(:for_gravatar).returns(true)
      end
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end

    describe "when the upload is used for a custom emoji" do
      it "returns false" do
        CustomEmoji.create(name: 'meme', upload: upload)
        expect(subject.should_be_secure?).to eq(false)
      end
    end

    describe "when it is based on a regular emoji" do
      it "returns false" do
        falafel = Emoji.all.find { |e| e.url == '/images/emoji/twitter/falafel.png?v=9' }
        upload.update!(origin: "http://localhost:3000#{falafel.url}")
        expect(subject.should_be_secure?).to eq(false)
      end
    end
  end

  context "when secure media is enabled" do
    before do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3-upload-bucket"
      SiteSetting.s3_access_key_id = "some key"
      SiteSetting.s3_secret_access_key = "some secrets3_region key"
      SiteSetting.secure_media = true
    end

    context "when login_required" do
      before do
        SiteSetting.login_required = true
      end
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end
    end

    context "when the access control post has_secure_media?" do
      before do
        upload.update(access_control_post_id: post_in_secure_context.id)
      end
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end

      context "when the post is deleted" do
        before do
          post_in_secure_context.trash!
        end
        it "still determines whether the post has secure media; returns true" do
          expect(subject.should_be_secure?).to eq(true)
        end
      end
    end

    context "when uploading in the composer" do
      let(:type) { "composer" }
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end
    end
    context "when uploading for a group message" do
      before do
        upload.stubs(:for_group_message).returns(true)
      end
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end
    end
    context "when uploading for a PM" do
      before do
        upload.stubs(:for_private_message).returns(true)
      end
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end
    end
    context "when upload is already secure" do
      before do
        upload.update(secure: true)
      end
      it "returns true" do
        expect(subject.should_be_secure?).to eq(true)
      end
    end

    context "for attachments" do
      before do
        upload.update(original_filename: 'test.pdf')
      end

      context "when the access control post has_secure_media?" do
        before do
          upload.update(access_control_post: post_in_secure_context)
        end
        it "returns true" do
          expect(subject.should_be_secure?).to eq(true)
        end
      end
    end
  end

  context "when secure media is disabled" do
    before do
      SiteSetting.secure_media = false
    end
    it "returns false" do
      expect(subject.should_be_secure?).to eq(false)
    end

    context "for attachments" do
      before do
        upload.update(original_filename: 'test.pdf')
      end
      it "returns false" do
        expect(subject.should_be_secure?).to eq(false)
      end
    end
  end
end
