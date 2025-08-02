# frozen_string_literal: true

RSpec.describe TopicUploadSecurityManager do
  subject(:manager) { described_class.new(topic) }

  let(:group) { Fabricate(:group) }
  let(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, user: user, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post1) { Fabricate(:post, topic: topic) }
  let!(:post2) { Fabricate(:post, topic: topic) }
  let!(:post3) { Fabricate(:post, topic: topic) }
  let!(:post4) { Fabricate(:post, topic: topic) }

  context "when a topic has posts linked to secure uploads" do
    let!(:upload) { Fabricate(:secure_upload) }
    let!(:upload2) { Fabricate(:secure_upload) }
    let!(:upload3) { Fabricate(:secure_upload) }

    before do
      UploadReference.create(upload: upload, target: post2)
      UploadReference.create(upload: upload2, target: post3)
      upload.update(access_control_post: post2)
      upload2.update(access_control_post: post3)
    end

    context "when the topic category is read restricted" do
      let(:category) { Fabricate(:private_category, group: group) }

      context "when secure uploads is enabled" do
        before do
          setup_s3
          SiteSetting.secure_uploads = true

          [upload, upload2, upload3].each { |upl| stub_upload(upl) }
        end

        it "does not change any upload statuses or update ACLs or rebake" do
          expect_upload_status_not_to_change
        end

        context "when changing the topic to a non-private category" do
          before { topic.update(category: Fabricate(:category)) }
          it "changes the upload secure statuses to false and updates ACLs and rebakes" do
            expect_upload_status_to_change_and_rebake
          end
        end
      end

      context "when secure uploads is disabled" do
        it "changes the upload secure statuses to false and updates ACLs and rebakes" do
          expect_upload_status_to_change_and_rebake
        end
      end
    end

    context "when the topic is a private message" do
      let(:topic) { Fabricate(:private_message_topic, category: category, user: user) }

      context "when secure uploads is enabled" do
        before do
          setup_s3
          SiteSetting.secure_uploads = true

          [upload, upload2, upload3].each { |upl| stub_upload(upl) }
        end

        it "does not change any upload statuses or update ACLs or rebake" do
          expect_upload_status_not_to_change
        end

        context "when making the PM into a public topic" do
          before { topic.update(archetype: Archetype.default) }
          it "changes the upload secure statuses to false and updates ACLs and rebakes" do
            expect_upload_status_to_change_and_rebake
          end
        end
      end

      context "when secure uploads is disabled" do
        it "changes the upload secure statuses to false and updates ACLs and rebakes" do
          expect_upload_status_to_change_and_rebake
        end
      end
    end

    context "when the topic is public" do
      context "when secure uploads is enabled" do
        before do
          setup_s3
          SiteSetting.secure_uploads = true

          [upload, upload2, upload3].each { |upl| stub_upload(upl) }
        end

        context "when login required is enabled" do
          before { SiteSetting.login_required = true }

          it "does not change any upload statuses or update ACLs or rebake" do
            expect_upload_status_not_to_change
          end
        end

        context "when login required is not enabled" do
          before { SiteSetting.login_required = false }

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
        setup_s3
        SiteSetting.secure_uploads = true

        [upload, upload2, upload3].each { |upl| stub_upload(upl) }
      end

      context "when this is the first post the upload has appeared in" do
        before { UploadReference.create(upload: upload3, target: post4) }

        it "changes the upload secure status to true and changes the ACL and rebakes the post and sets the access control post" do
          Post.any_instance.expects(:rebake!).once
          manager.run
          expect(upload3.reload.secure?).to eq(true)
          expect(upload3.reload.access_control_post).to eq(post4)
        end

        context "when secure uploads is not enabled" do
          before { SiteSetting.secure_uploads = false }

          it "does not change the upload secure status and does not set the access control post" do
            manager.run
            expect(upload3.reload.secure?).to eq(false)
            expect(upload3.reload.access_control_post).to eq(nil)
          end
        end
      end

      context "when this is not the first post the upload has appeared in" do
        before do
          UploadReference.create(upload: upload3, target: Fabricate(:post))
          UploadReference.create(upload: upload3, target: post4)
        end

        it "does not change the upload secure status and does not set the access control post" do
          Post.any_instance.expects(:rebake!).never
          manager.run
          expect(upload3.reload.secure?).to eq(false)
          expect(upload3.reload.access_control_post).to eq(nil)
        end
      end
    end
  end

  def expect_upload_status_not_to_change
    Post.any_instance.expects(:rebake!).never
    manager.run
    expect(upload.reload.secure?).to eq(true)
    expect(upload2.reload.secure?).to eq(true)
  end

  def expect_upload_status_to_change_and_rebake
    Post.any_instance.expects(:rebake!).twice
    manager.run
    expect(upload.reload.secure?).to eq(false)
    expect(upload2.reload.secure?).to eq(false)
  end
end
