require 'spec_helper'

describe UploadsController do

  it 'requires you to be logged in' do
    -> { xhr :post, :create }.should raise_error(Discourse::NotLoggedIn)
  end

  context 'logged in' do

    before do
      @user = log_in :user
    end

    context '.create' do

      context 'missing params' do
        it 'raises an error without the topic_id param' do
          -> { xhr :post, :create }.should raise_error(Discourse::InvalidParameters)
        end
      end

      context 'correct params' do

        let(:logo) do
          ActionDispatch::Http::UploadedFile.new({
            filename: 'logo.png',
            type: 'image/png',
            tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
          })
        end

        let(:logo_dev) do
          ActionDispatch::Http::UploadedFile.new({
            filename: 'logo-dev.png',
            type: 'image/png',
            tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo-dev.png")
          })
        end

        let(:text_file) do
          ActionDispatch::Http::UploadedFile.new({
            filename: 'LICENSE.txt',
            type: 'text/plain',
            tempfile: File.new("#{Rails.root}/LICENSE.txt")
          })
        end

        let(:files) { [ logo_dev, logo ] }

        context 'with a file' do
          it 'is succesful' do
            xhr :post, :create, topic_id: 1234, file: logo
            response.should be_success
          end

          it 'supports only images' do
            xhr :post, :create, topic_id: 1234, file: text_file
            response.status.should eq 415
          end
        end

        context 'with some files' do

          it 'is succesful' do
            xhr :post, :create, topic_id: 1234, files: files
            response.should be_success
          end

          it 'takes the first file' do
            xhr :post, :create, topic_id: 1234, files: files
            response.body.should match /logo-dev.png/
          end

        end

      end

    end

  end

end
