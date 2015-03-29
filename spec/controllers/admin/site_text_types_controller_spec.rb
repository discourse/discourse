require 'spec_helper'

describe Admin::SiteTextTypesController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextTypesController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context ' .index' do
      it 'returns success' do
        xhr :get, :index
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end
    end
  end

end
