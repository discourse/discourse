require 'rails_helper'

RSpec.describe Admin::EmojisController do
  let(:admin) { Fabricate(:admin) }
  let(:upload) { Fabricate(:upload) }

  before do
    sign_in(admin)
  end

  describe "#create" do
    describe 'when upload is invalid' do
      it 'should publish the right error' do
        message = MessageBus.track_publish("/uploads/emoji") do
          post "/admin/customize/emojis.json", params: {
            name: 'test',
            file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/fake.jpg")
          }
        end.first

        expect(message.data["errors"]).to eq([I18n.t('upload.images.size_not_found')])
      end
    end

    describe 'when emoji name already exists' do
      it 'should publish the right error' do
        CustomEmoji.create!(name: 'test', upload: upload)

        message = MessageBus.track_publish("/uploads/emoji") do
          post "/admin/customize/emojis.json", params: {
            name: 'test',
            file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png")
          }
        end.first

        expect(message.data["errors"]).to eq([
          "Name #{I18n.t('activerecord.errors.models.custom_emoji.attributes.name.taken')}"
        ])
      end
    end

    it 'should allow an admin to add a custom emoji' do
      Emoji.expects(:clear_cache)

        message = MessageBus.track_publish("/uploads/emoji") do
          post "/admin/customize/emojis.json", params: {
            name: 'test',
            file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png")
          }
        end.first

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq('logo.png')
        expect(message.data["errors"]).to eq(nil)
        expect(message.data["name"]).to eq(custom_emoji.name)
        expect(message.data["url"]).to eq(upload.url)
    end
  end

  describe '#destroy' do
    it 'should allow an admin to delete a custom emoji' do
      custom_emoji = CustomEmoji.create!(name: 'test', upload: upload)
      Emoji.clear_cache

      expect do
        delete "/admin/customize/emojis/#{custom_emoji.name}.json",
          params: { name: 'test' }
      end.to change { Upload.count }.by(-1).and change { CustomEmoji.count }.by(-1)
    end
  end
end
