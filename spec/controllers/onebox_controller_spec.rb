require 'rails_helper'

describe OneboxController do

  let(:url) { "http://google.com" }

  it "requires the user to be logged in" do
    expect { xhr :get, :show, url: url }.to raise_error(Discourse::NotLoggedIn)
  end

  describe "logged in" do

    before { @user = log_in(:admin) }

    it 'invalidates the cache if refresh is passed' do
      Oneboxer.expects(:preview).with(url, invalidate_oneboxes: true)
      xhr :get, :show, url: url, refresh: 'true', user_id: @user.id
    end

    describe "cached onebox" do

      let(:body) { "This is a cached onebox body" }

      before do
        Oneboxer.expects(:cached_preview).with(url).returns(body)
        Oneboxer.expects(:preview).never
        xhr :get, :show, url: url, user_id: @user.id
      end

      it "returns success" do
        expect(response).to be_success
      end

      it "returns the cached onebox response in the body" do
        expect(response.body).to eq(body)
      end

    end

    describe "only 1 outgoing preview per user" do

      it "returns 429" do
        Oneboxer.expects(:is_previewing?).returns(true)
        xhr :get, :show, url: url, user_id: @user.id
        expect(response.status).to eq(429)
      end

    end

    describe "found onebox" do

      let(:body) { "this is the onebox body"}

      before do
        Oneboxer.expects(:preview).with(url, invalidate_oneboxes: false).returns(body)
        xhr :get, :show, url: url, user_id: @user.id
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
        xhr :get, :show, url: url, user_id: @user.id
        expect(response.response_code).to eq(404)
      end

      it "returns 404 if the onebox is an empty string" do
        Oneboxer.expects(:preview).with(url, invalidate_oneboxes: false).returns(" \t ")
        xhr :get, :show, url: url, user_id: @user.id
        expect(response.response_code).to eq(404)
      end

    end

  end

end
