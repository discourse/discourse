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
      SQL
      user: user
    ).tap(&:link_post_uploads)
  end

  let(:upload_recovery) { UploadRecovery.new }

  before do
    SiteSetting.authorized_extensions = 'png|pdf'
    SiteSetting.queue_jobs = false
  end

  after do
    [upload, upload2].each do |u|
      next if u
      public_path = "#{Discourse.store.public_dir}#{u.url}"

      [
        public_path,
        public_path.sub("uploads", "uploads/tombstone")
      ].each { |path| File.delete(path) if File.exists?(path) }
    end
  end

  describe '#recover' do
    describe 'when given an invalid sha1' do
      it 'should not do anything' do
        upload_recovery.expects(:recover_from_local).never

        post.update!(
          raw: "![logo.png](upload://#{'a' * 28}.png)"
        )

        upload_recovery.recover

        post.update!(
          raw: "<a href=#{"/uploads/test/original/3X/a/6%0A/#{upload.sha1}.png"}>test</a>"
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

    describe 'for a missing attachment' do
      let(:post) do
        Fabricate(:post,
          raw: <<~SQL,
          <a class="attachment" href="#{upload2.url}">some.pdf</a>
          <a>blank</a>
          SQL
          user: user
        ).tap(&:link_post_uploads)
      end

      it 'should recover the attachment' do
        expect do
          upload2.destroy!
        end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do
          upload_recovery.recover
        end.to change { post.reload.uploads.count }.from(0).to(1)

        expect(File.read(Discourse.store.path_for(post.uploads.first)))
          .to eq(File.read(file_from_fixtures("small.pdf", "pdf")))
      end
    end

    it 'should recover uploads and attachments' do
      stub_request(:get, "http://test.localhost#{upload.url}")
        .to_return(status: 200)

      expect do
        upload.destroy!
      end.to change { post.reload.uploads.count }.from(1).to(0)

      expect do
        upload_recovery.recover
      end.to change { post.reload.uploads.count }.from(0).to(1)

      expect(File.read(Discourse.store.path_for(post.uploads.first)))
        .to eq(File.read(file_from_fixtures("smallest.png")))
    end
  end

  describe "#recover_user_profile_backgrounds" do
    before do
      user.user_profile.update!(
        profile_background: upload.url,
        card_background: upload.url
      )
    end

    it "should recover the background uploads" do
      user_profile = user.user_profile
      upload.destroy!

      user_profile.update_columns(
        profile_background: user_profile.profile_background.sub("default", "X"),
        card_background: user_profile.card_background.sub("default", "X")
      )

      expect do
        upload_recovery.recover_user_profile_backgrounds
      end.to change { Upload.count }.by(1)

      user_profile.reload

      expect(user_profile.profile_background).to eq(upload.url)
      expect(user_profile.card_background).to eq(upload.url)
    end

    describe 'for a bad upload' do
      it 'should not update the urls' do
        user_profile = user.user_profile
        upload.destroy!

        profile_background = user_profile.profile_background.sub("default", "X")
        card_background = user_profile.card_background.sub("default", "X")

        user_profile.update_columns(
          profile_background: profile_background,
          card_background: card_background
        )

        SiteSetting.authorized_extensions = ''

        expect do
          upload_recovery.recover_user_profile_backgrounds
        end.to_not change { Upload.count }

        user_profile.reload

        expect(user_profile.profile_background).to eq(profile_background)
        expect(user_profile.card_background).to eq(card_background)
      end
    end
  end
end
