require 'rails_helper'
require_dependency "upload_recovery"

RSpec.describe UploadRecovery do
  let(:user) { Fabricate(:user) }

  let(:upload) do
    UploadCreator.new(
      file_from_fixtures("smallest.png"),
      "logo.png"
    ).create_for(user.id)
  end

  let(:upload2) do
    UploadCreator.new(
      file_from_fixtures("small.pdf", "pdf"),
      "some.pdf"
    ).create_for(user.id)
  end

  let(:post) do
    Fabricate(:post,
      raw: <<~SQL,
      ![logo.png](#{upload.short_url})
      <a class="attachment" href="#{upload2.url}">some.pdf</a>
      SQL
      user: user
    ).tap(&:link_post_uploads)
  end

  let(:upload_recovery) { UploadRecovery.new }

  before do
    SiteSetting.authorized_extensions = 'png|pdf'
    SiteSetting.queue_jobs = false
  end

  describe '#recover' do
    after do
      [upload, upload2].each do |u|
        public_path = "#{Discourse.store.public_dir}#{u.url}"

        [
          public_path,
          public_path.sub("uploads", "uploads/tombstone")
        ].each { |path| File.delete(path) if File.exists?(path) }
      end
    end

    describe 'when given an invalid sha1' do
      it 'should not do anything' do
        upload_recovery.expects(:recover_from_local).never

        post.update!(
          raw: "![logo.png](upload://#{'a' * 28}.png)"
        )

        upload_recovery.recover
      end
    end

    it 'accepts a custom ActiveRecord relation' do
      post.update!(updated_at: 2.days.ago)
      upload.destroy!

      upload_recovery.expects(:recover_from_local).never
      upload_recovery.recover(Post.where("updated_at >= ?", 1.day.ago))
    end

    it 'should recover uploads and attachments' do
      stub_request(:get, "http://test.localhost#{upload.url}")
        .to_return(status: 200)

      expect do
        upload.destroy!
        upload2.destroy!
      end.to change { post.reload.uploads.count }.from(2).to(0)

      expect do
        upload_recovery.recover
      end.to change { post.reload.uploads.count }.from(0).to(2)
    end
  end
end
