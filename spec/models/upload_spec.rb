require 'spec_helper'

describe Upload do

  it { should belong_to :user }
  it { should belong_to :topic }

  it { should validate_presence_of :original_filename }
  it { should validate_presence_of :filesize }

  context '.create_for' do

    let(:user_id) { 1 }
    let(:topic_id) { 42 }

    let(:logo) do
      ActionDispatch::Http::UploadedFile.new({
        filename: 'logo.png',
        content_type: 'image/png',
        tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
      })
    end

    it "uses imgur when it is enabled" do
      SiteSetting.stubs(:enable_imgur?).returns(true)
      Upload.expects(:create_on_imgur).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    it "uses s3 when it is enabled" do
      SiteSetting.stubs(:enable_s3_uploads?).returns(true)
      Upload.expects(:create_on_s3).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    it "uses local storage otherwise" do
      Upload.expects(:create_locally).with(user_id, logo, topic_id)
      Upload.create_for(user_id, logo, topic_id)
    end

    context 'imgur' do

      # TODO

    end

    context 's3' do

      # TODO

    end

    context 'local' do

      # TODO

    end

  end

end
