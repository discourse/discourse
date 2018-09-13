require 'rails_helper'
require_dependency "upload_recovery"

RSpec.describe UploadRecovery do
  let(:user) { Fabricate(:user) }

  let(:upload) do
    UploadCreator.new(
      file_from_fixtures("logo.png"),
      "logo.png"
    ).create_for(user.id)
  end

  let(:post) do
    Fabricate(:post,
      raw: "![logo.png](#{upload.short_url})",
      user: user
    ).link_post_uploads
  end

  before do
    SiteSetting.queue_jobs = false
  end

  describe '#recover' do
    it 'should recover the upload' do
      begin
        stub_request(:get, "http://test.localhost#{upload.url}")
          .to_return(status: 200)

        expect do
          upload.destroy!
        end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do
          UploadRecovery.new.recover
        end.to change { post.reload.uploads.count }.from(0).to(1)
      ensure
        public_path = "#{Discourse.store.public_dir}#{upload.url}"

        [
          public_path,
          public_path.sub("uploads", "uploads/tombstone")
        ].each { |path| File.delete(path) if File.exists?(path) }
      end
    end
  end
end
