require 'spec_helper'

describe Admin::SiteTextsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.show' do
      let(:text_type) { SiteText.text_types.first.text_type }

      it 'returns success' do
        xhr :get, :show, id: text_type
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :show, id: text_type
        expect(::JSON.parse(response.body)).to be_present
      end
    end
  end

end
