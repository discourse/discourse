require 'rails_helper'

describe OneboxController do

  let(:url) { "http://google.com" }

  it 'invalidates the cache if refresh is passed' do
    Oneboxer.expects(:preview).with(url, invalidate_oneboxes: true)
    xhr :get, :show, url: url, refresh: 'true'
  end

  describe "found onebox" do

    let(:body) { "this is the onebox body"}

    before do
      Oneboxer.expects(:preview).with(url, invalidate_oneboxes: false).returns(body)
      xhr :get, :show, url: url
    end

    it 'returns success' do
      expect(response).to be_success
    end

    it 'returns the onebox response in the body' do
      expect(response.body).to eq(body)
    end

  end

  describe "missing onebox" do

    it "returns 404 if the onebox is nil" do
      Oneboxer.expects(:preview).with(url, invalidate_oneboxes: false).returns(nil)
      xhr :get, :show, url: url
      expect(response.response_code).to eq(404)
    end

    it "returns 404 if the onebox is an empty string" do
      Oneboxer.expects(:preview).with(url, invalidate_oneboxes: false).returns(" \t ")
      xhr :get, :show, url: url
      expect(response.response_code).to eq(404)
    end

  end

end
