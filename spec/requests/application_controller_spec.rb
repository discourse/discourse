require 'rails_helper'

RSpec.describe ApplicationController do

  describe '#check_force_https' do

    before do
      AdminDashboardData.clear_problem_message(ApplicationController::FORCE_HTTPS_WARNING_KEY)
    end

    it "should not warn for `http` protocol" do
      get '/'
      expect(ApplicationController.force_https_warning).to eq(nil)
    end

    it "should warn for `https` protocol" do
      get '/', params: {}, headers: { 'HTTPS' => 'on' }
      expect(ApplicationController.force_https_warning).to eq(I18n.t(ApplicationController::FORCE_HTTPS_WARNING_KEY))
    end
  end
end
