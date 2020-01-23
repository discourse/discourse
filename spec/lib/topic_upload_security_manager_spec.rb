# frozen_string_literal: true

require 'rails_helper'

describe TopicUploadSecurityManager do
  let(:group) { Fabricate(:group) }
  let(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, user: user, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post1) { Fabricate(:post, topic: topic) }
  let!(:post2) { Fabricate(:post, topic: topic) }
  let!(:post3) { Fabricate(:post, topic: topic) }
  let!(:post4) { Fabricate(:post, topic: topic) }

  subject { described_class.new(topic) }

  context "when a topic has posts linked to secure uploads" do
    let!(:upload) { Fabricate(:secure_upload) }
    let!(:upload2) { Fabricate(:secure_upload) }
    let!(:upload3) { Fabricate(:secure_upload) }

    before do
      PostUpload.create(upload: upload, post: post2)
      PostUpload.create(upload: upload2, post: post3)
      upload.update(access_control_post: post2)
      upload2.update(access_control_post: post3)
    end

    context "when the topic category is read restricted" do
      let(:category) { Fabricate(:private_category, group: group) }

      context "when secure media is enabled" do
        before { enable_secure_media }

        it "does not change any upload statuses or update ACLs or rebake" do
          expect_upload_status_not_to_change
        end

        context "when changing the topic to a non-private category" do
          before do
            topic.update(category: Fabricate(:category))
          end
          it "changes the upload secure statuses to false and updates ACLs and rebakes" do
            expect_upload_status_to_change_and_rebake
          end
        end
      end

      context "when secure media is disabled" do
        it "changes the upload secure statuses to false and updates ACLs and rebakes" do
          expect_upload_status_to_change_and_rebake
        end
      end
    end

    context "when the topic is a private message" do
      let(:topic) { Fabricate(:private_message_topic, category: category, user: user) }

      context "when secure media is enabled" do
        before { enable_secure_media }

        it "does not change any upload statuses or update ACLs or rebake" do
          expect_upload_status_not_to_change
        end

        context "when making the PM into a public topic" do
          before do
            topic.update(archetype: Archetype.default)
          end
          it "changes the upload secure statuses to false and updates ACLs and rebakes" do
            expect_upload_status_to_change_and_rebake
          end
        end
      end

      context "when secure media is disabled" do
        it "changes the upload secure statuses to false and updates ACLs and rebakes" do
          expect_upload_status_to_change_and_rebake
        end
      end
    end

    context "when the topic is public" do
      context "when secure media is enabled" do
        before { enable_secure_media }

        context "when login required is enabled" do
          before do
            SiteSetting.login_required = true
          end

          it "does not change any upload statuses or update ACLs or rebake" do
            expect_upload_status_not_to_change
          end
        end

        context "when login required is not enabled" do
          before do
            SiteSetting.login_required = false
          end

          it "changes the upload secure statuses to false and updates ACLs and rebakes" do
            expect_upload_status_to_change_and_rebake
          end
        end
      end
    end

    context "when one of the posts has an upload without an access control post" do
      let(:category) { Fabricate(:private_category, group: group) }
      let!(:upload3) { Fabricate(:upload) }

      before do
        enable_secure_media
      end

      context "when this is the first post the upload has appeared in" do
        before do
          PostUpload.create(upload: upload3, post: post4)
        end

        it "changes the upload secure status to true and changes the ACL and rebakes the post and sets the access control post" do
          expect(Post.any_instance.expects(:rebake!).once)
          subject.run
          expect(upload3.reload.secure?).to eq(true)
          expect(upload3.reload.access_control_post).to eq(post4)
        end

        context "when secure media is not enabled" do
          before do
            SiteSetting.secure_media = false
          end

          it "does not change the upload secure status and does not set the access control post" do
            subject.run
            expect(upload3.reload.secure?).to eq(false)
            expect(upload3.reload.access_control_post).to eq(nil)
          end
        end
      end

      context "when this is not the first post the upload has appeared in" do
        before do
          PostUpload.create(upload: upload3, post: Fabricate(:post))
          PostUpload.create(upload: upload3, post: post4)
        end

        it "does not change the upload secure status and does not set the access control post" do
          expect(Post.any_instance.expects(:rebake!).never)
          subject.run
          expect(upload3.reload.secure?).to eq(false)
          expect(upload3.reload.access_control_post).to eq(nil)
        end
      end
    end
  end

  def enable_secure_media
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "some key"
    SiteSetting.s3_secret_access_key = "some secrets3_region key"
    SiteSetting.secure_media = true

    stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")

    # because the ACLs will be changing...
    [upload, upload2, upload3].each do |upl|
      stub_request(
        :put,
        "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/original/1X/#{upl.sha1}.#{upl.extension}?acl"
      )
    end
  end

  def expect_upload_status_not_to_change
    expect(Post.any_instance.expects(:rebake!).never)
    subject.run
    expect(upload.reload.secure?).to eq(true)
    expect(upload2.reload.secure?).to eq(true)
  end

  def expect_upload_status_to_change_and_rebake
    expect(Post.any_instance.expects(:rebake!).twice)
    subject.run
    expect(upload.reload.secure?).to eq(false)
    expect(upload2.reload.secure?).to eq(false)
  end
end
