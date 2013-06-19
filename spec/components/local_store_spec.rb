require 'spec_helper'
require 'local_store'

describe LocalStore do

  describe "store_file" do

    let(:file) do
      ActionDispatch::Http::UploadedFile.new({
        filename: 'logo.png',
        content_type: 'image/png',
        tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
      })
    end

    let(:image_info) { FastImage.new(file) }

    it 'returns the url of the uploaded file if successful' do
      # prevent the tests from creating directories & files...
      FileUtils.stubs(:mkdir_p)
      File.stubs(:open)
      # The Time needs to be frozen as it is used to generate a clean & unique name
      Time.stubs(:now).returns(Time.utc(2013, 2, 17, 12, 0, 0, 0))
      #
      LocalStore.store_file(file, "", image_info, 1).should == '/uploads/default/1/253dc8edf9d4ada1.png'
    end

  end

end
