# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SafeModeController do
  describe 'enter' do
    context 'when no params are given' do
      it 'should redirect back to safe mode page' do
        post '/safe-mode'
        expect(response.status).to redirect_to(safe_mode_path)
      end
    end

    context 'when safe mode is not enabled' do
      it 'should raise an error' do
        SiteSetting.enable_safe_mode = false
        post '/safe-mode'
        expect(response.status).to eq(404)
      end

      it "doesn't raise an error for staff" do
        SiteSetting.enable_safe_mode = false
        sign_in(Fabricate(:moderator))
        post '/safe-mode'
        expect(response.status).to redirect_to(safe_mode_path)
      end
    end

  end
end
