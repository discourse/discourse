# frozen_string_literal: true

require 'rails_helper'

describe UserActivator do
  fab!(:user) { Fabricate(:user) }
  let!(:email_token) { Fabricate(:email_token, user: user) }

  describe 'email_activator' do
    let(:activator) { EmailActivator.new(user, nil, nil, nil) }

    it 'create email token and enqueues user email' do
      now = freeze_time
      activator.activate
      email_token = user.reload.email_tokens.last
      expect(email_token.created_at).to eq_time(now)
      job_args = Jobs::CriticalUserEmail.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(user.id)
      expect(job_args["type"]).to eq("signup")
      expect(EmailToken.hash_token(job_args["email_token"])).to eq(email_token.token_hash)
    end
  end
end
