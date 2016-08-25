require 'rails_helper'

describe ExtraLocalesController do

  context 'show' do

    it "needs a valid bundle" do
      get :show, bundle: 'made-up-bundle'
      expect(response).to_not be_success
      expect(response.body).to be_blank
    end

    it "won't work with a weird parameter" do
      get :show, bundle: '-invalid..character!!'
      expect(response).to_not be_success
    end

    it "works with a valid bundle" do
      get :show, bundle: 'admin'
      expect(response).to be_success
      expect(response.body).to be_present
    end
  end

end
