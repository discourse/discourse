require 'spec_helper'
require 'imgur'

describe Imgur do

  describe "upload_file" do

    let(:file) { Rails.root.join('app', 'assets', 'images', 'logo.png') }
    let(:params) { [SiteSetting.imgur_endpoint, { image: Base64.encode64(file.read) }, { 'Authorization' => "Client-ID #{SiteSetting.imgur_client_id}" }] }

    it 'returns JSON of the Imgur upload if successful' do
      json = {
        data: {
          id: 'fake',
          link: 'http://imgur.com/fake.png',
          deletehash: 'a3kaoad30'
        },
        success: true,
        status: 200
      }.to_json

      response = mock
      response.expects(:body).returns(json)

      image_info = {
        url: 'http://imgur.com/fake.png',
        filesize: File.size(file)
      }

      RestClient.expects(:post).with(*params).returns(response)
      result = Imgur.upload_file(file)

      # Not testing what width/height actually are because ImageSizer is already tested
      result[:url].should eq(image_info[:url])
      result[:filesize].should eq(image_info[:filesize])
      result[:width].should_not be_nil
      result[:height].should_not be_nil
    end

    it 'returns nil if the request fails' do
      json = {
        success: false,
        status: 400
      }.to_json

      response = mock
      response.expects(:body).returns(json)
      RestClient.expects(:post).with(*params).returns(response)

      Imgur.upload_file(file).should be_nil
    end

  end

end
