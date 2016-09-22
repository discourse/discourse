require 'rails_helper'

describe ExtraLocalesController do

  context 'show' do
    before do
      I18n.locale = :en
      I18n.reload!
    end

    it "needs a valid bundle" do
      get :show, bundle: 'made-up-bundle'
      expect(response).to_not be_success
      expect(response.body).to be_blank
    end

    it "won't work with a weird parameter" do
      get :show, bundle: '-invalid..character!!'
      expect(response).to_not be_success
    end
  end

end
