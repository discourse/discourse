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

  context 'site setting uploads' do
    let(:provider) { SiteSettings::DbProvider.new(SiteSetting) }
    fab!(:upload) { Fabricate(:upload) }
    fab!(:upload2) { Fabricate(:upload) }

    it 'creates upload references for uploads' do
      expect { provider.save('logo', upload.id, SiteSettings::TypeSupervisor.types[:upload]) }
        .to change { UploadReference.count }.by(1)

      upload_reference = UploadReference.last
      expect(upload_reference.upload).to eq(upload)
      expect(upload_reference.target).to eq(SiteSetting.find_by(name: 'logo'))

      expect { provider.destroy('logo') }
        .to change { UploadReference.count }.by(-1)
    end

    it 'creates upload references for uploaded_image_lists' do
      expect { provider.save('selectable_avatars', "#{upload.id}|#{upload2.id}", SiteSettings::TypeSupervisor.types[:uploaded_image_list]) }
        .to change { UploadReference.count }.by(2)

      upload_references = UploadReference.all.where(target: SiteSetting.find_by(name: 'selectable_avatars'))
      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)

      expect { provider.destroy('selectable_avatars') }
        .to change { UploadReference.count }.by(-2)
    end
  end
end
