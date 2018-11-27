require 'rails_helper'

RSpec.describe UploadCreator do
  let(:user) { Fabricate(:user) }

  describe '#create_for' do
    describe 'when upload is not an image' do
      before do
        SiteSetting.authorized_extensions = 'txt'
      end

      let(:filename) { "utf-8.txt" }
      let(:file) { file_from_fixtures(filename, "encodings") }

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, "utf-8\n.txt").create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('txt')
        expect(File.extname(upload.url)).to eq('.txt')
        expect(upload.original_filename).to eq('utf-8.txt')
        expect(user.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(1)

        user2 = Fabricate(:user)

        expect do
          UploadCreator.new(file, "utf-8\n.txt").create_for(user2.id)
        end.to change { Upload.count }.by(0)

        expect(user.user_uploads.count).to eq(1)
        expect(user2.user_uploads.count).to eq(1)
        expect(upload.user_uploads.count).to eq(2)
      end
    end

    describe 'when image is not authorized' do
      describe 'when image is for site setting' do
        let(:filename) { 'logo.png' }
        let(:file) { file_from_fixtures(filename) }

        before do
          SiteSetting.authorized_extensions = 'jpg'
        end

        it 'should create the right upload' do
          upload = UploadCreator.new(file, filename,
            for_site_setting: true
          ).create_for(Discourse.system_user.id)

          expect(upload.persisted?).to eq(true)
          expect(upload.original_filename).to eq(filename)
        end
      end
    end

    describe 'when image has the wrong extension' do
      let(:filename) { "png_as.bin" }
      let(:file) { file_from_fixtures(filename) }

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, filename,
            force_optimize: true,
            type: UploadCreator::TYPES_TO_CROP.first
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('png')
        expect(File.extname(upload.url)).to eq('.png')
        expect(upload.original_filename).to eq('png_as.png')
      end

      describe 'for webp format' do
        before do
          SiteSetting.authorized_extensions = '.webp|.bin'
        end

        let(:filename) { "webp_as.bin" }
        let(:file) { file_from_fixtures(filename) }

        it 'should not correct the coerce filename' do
          expect do
            UploadCreator.new(file, filename).create_for(user.id)
          end.to change { Upload.count }.by(1)

          upload = Upload.last

          expect(upload.extension).to eq('bin')
          expect(File.extname(upload.url)).to eq('.bin')
          expect(upload.original_filename).to eq('webp_as.bin')
        end
      end
    end

    describe 'converting to jpeg' do
      let(:filename) { "should_be_jpeg.png" }
      let(:file) { file_from_fixtures(filename) }

      let(:small_filename) { "logo.png" }
      let(:small_file) { file_from_fixtures(small_filename) }

      before do
        SiteSetting.png_to_jpg_quality = 1
      end

      it 'should not store file as jpeg if it does not meet absolute byte saving requirements' do

        # logo.png is 2297 bytes, converting to jpeg saves 30% but does not meet
        # the absolute savings required of 25_000 bytes, if you save less than that
        # skip this

        expect do
          UploadCreator.new(small_file, small_filename,
            pasted: true,
            force_optimize: true
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('png')
        expect(File.extname(upload.url)).to eq('.png')
        expect(upload.original_filename).to eq('logo.png')

      end

      it 'should store the upload with the right extension' do
        expect do
          UploadCreator.new(file, filename,
            pasted: true,
            force_optimize: true
          ).create_for(user.id)
        end.to change { Upload.count }.by(1)

        upload = Upload.last

        expect(upload.extension).to eq('jpeg')
        expect(File.extname(upload.url)).to eq('.jpeg')
        expect(upload.original_filename).to eq('should_be_jpeg.jpg')
      end
    end
  end
end
