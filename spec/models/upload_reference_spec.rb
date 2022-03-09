# frozen_string_literal: true

describe UploadReference do
  context 'post uploads' do
    fab!(:upload) { Fabricate(:upload) }
    fab!(:post) { Fabricate(:post, raw: "[](#{upload.short_url})") }

    it 'creates upload references' do
      expect { post.link_post_uploads }
        .to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(post)

      expect { post.destroy! }
        .to change { UploadReference.count }.by(-1)
    end
  end
end
