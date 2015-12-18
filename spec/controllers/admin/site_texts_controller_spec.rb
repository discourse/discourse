require 'rails_helper'

describe Admin::SiteTextsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.index' do
      it 'returns json' do
        xhr :get, :index, q: 'title'
        expect(response).to be_success
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context '.show' do
      it 'returns a site text for a key that exists' do
        xhr :get, :show, id: 'title'
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(I18n.t(:title))
      end

      it 'returns not found for missing keys' do
        xhr :get, :show, id: 'made_up_no_key_exists'
        expect(response).not_to be_success
      end
    end

    context '.update and .revert' do
      it 'updates and reverts the key' do
        orig_title = I18n.t(:title)

        xhr :put, :update, id: 'title', site_text: {value: 'hello'}
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('hello')


        # Revert
        xhr :put, :revert, id: 'title'
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(orig_title)
      end

      it 'returns not found for missing keys' do
        xhr :put, :update, id: 'made_up_no_key_exists', site_text: {value: 'hello'}
        expect(response).not_to be_success
      end

      it 'logs the change' do
        StaffActionLogger.any_instance.expects(:log_site_text_change).once
        xhr :put, :update, id: 'title', site_text: {value: 'hello'}
      end
    end
  end

end
