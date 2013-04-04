require 'spec_helper'

describe Admin::SiteContentsController do

  it "is a subclass of AdminController" do
    (Admin::SiteContentsController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.show' do
      let(:content_type) { SiteContent.content_types.first.content_type }

      it 'returns success' do
        xhr :get, :show, id: content_type
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :show, id: content_type
        ::JSON.parse(response.body).should be_present
      end
    end
  end

end
