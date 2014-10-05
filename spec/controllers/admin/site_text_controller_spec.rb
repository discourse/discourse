require 'spec_helper'

describe Admin::SiteTextController do

  it "is a subclass of AdminController" do
    (Admin::SiteTextController < Admin::AdminController).should == true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.show' do
      let(:text_type) { SiteText.text_types.first.text_type }

      it 'returns success' do
        xhr :get, :show, id: text_type
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :show, id: text_type
        ::JSON.parse(response.body).should be_present
      end
    end
  end

end
