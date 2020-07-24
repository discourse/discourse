# frozen_string_literal: true

require 'rails_helper'

describe UserActivator do

  describe 'email_activator' do

    it 'does not create new email token unless required' do
      SiteSetting.email_token_valid_hours = 24
      user = Fabricate(:user)
      activator = EmailActivator.new(user, nil, nil, nil)

      expect_enqueued_with(job: :critical_user_email, args: { type: :signup, email_token: user.email_tokens.first.token }) do
        activator.activate
      end
    end

    it 'creates and send new email token if the existing token expired' do
      now = freeze_time

      SiteSetting.email_token_valid_hours = 24
      user = Fabricate(:user)
      email_token = user.email_tokens.first
      email_token.update_column(:created_at, 48.hours.ago)
      activator = EmailActivator.new(user, nil, nil, nil)

      expect_not_enqueued_with(job: :critical_user_email, args: { type: :signup, user_id: user.id, email_token: email_token.token }) do
        activator.activate
      end

      email_token = user.reload.email_tokens.last

      expect(job_enqueued?(job: :critical_user_email, args: {
        type: :signup,
        user_id: user.id,
        email_token: email_token.token
      })).to eq(true)

      expect(email_token.created_at).to eq_time(now)
    end

  end
end
