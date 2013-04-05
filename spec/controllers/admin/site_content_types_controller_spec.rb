require 'spec_helper'

describe Admin::SiteContentTypesController do

  it "is a subclass of AdminController" do
    (Admin::SiteContentTypesController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context ' .index' do
      it 'returns success' do
        xhr :get, :index
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        ::JSON.parse(response.body).should be_present
      end
    end
  end

end
