require 'spec_helper'
require 'discourse_imgur/imgur'

# /!\ WARNING /!\
# This plugin has been extracted from the Discourse source code and has not been tested.
# It really needs some love <3
# /!\ WARNING /!\

describe Imgur do

  describe "store_file" do

    let(:file) { Rails.root.join('app', 'assets', 'images', 'logo.png') }
    let(:image_info) { FastImage.new(file) }
    let(:params) { [SiteSetting.imgur_endpoint, { image: Base64.encode64(file.read) }, { 'Authorization' => "ClientID #{SiteSetting.imgur_client_id}" }] }

    before(:each) do
      SiteSetting.stubs(:imgur_endpoint).returns("imgur_endpoint")
      SiteSetting.stubs(:imgur_client_id).returns("imgur_client_id")
    end

    it 'returns the url of the Imgur upload if successful' do
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
      RestClient.expects(:post).with(*params).returns(response)

      Imgur.store_file(file, image_info, 1).should == 'http://imgur.com/fake.png'
    end

    it 'returns nil if the request fails' do
      json = {
        success: false,
        status: 400
      }.to_json

      response = mock
      response.expects(:body).returns(json)
      RestClient.expects(:post).with(*params).returns(response)

      Imgur.store_file(file, image_info, 1).should be_nil
    end

  end

end
