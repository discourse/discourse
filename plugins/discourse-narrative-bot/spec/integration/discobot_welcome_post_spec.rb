require 'rails_helper'

describe "Discobot welcome post" do
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.queue_jobs = true
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  after do
    Jobs::NarrativeInit.jobs.clear
  end

  context 'when discourse_narrative_bot_welcome_post_delay is 0' do
    it 'should not delay the welcome post' do
      user
      expect { sign_in(user) }.to_not change { Jobs::NarrativeInit.jobs.count }
    end
  end

  context 'When discourse_narrative_bot_welcome_post_delay is greater than 0' do
    before do
      SiteSetting.discourse_narrative_bot_welcome_post_delay = 5
    end

    context 'when user logs in normally' do
      it 'should delay the welcome post until user logs in' do
        expect { sign_in(user) }.to change { Jobs::NarrativeInit.jobs.count }.by(1)
        expect(Jobs::NarrativeInit.jobs.first["args"].first["user_id"]).to eq(user.id)
      end
    end

    context 'when user redeems an invite' do
      let(:invite) { Fabricate(:invite, invited_by: Fabricate(:admin), email: 'testing@gmail.com') }

      it 'should delay the welcome post until the user logs in' do
        invite

        expect do
          xhr :put, "/invites/show/#{invite.invite_key}",
            username: 'somename',
            name: 'testing',
            password: 'asodaasdaosdhq'
        end.to change { User.count }.by(1)

        expect(Jobs::NarrativeInit.jobs.first["args"].first["user_id"]).to eq(User.last.id)
      end
    end

    context 'when user redeems a disposable invite' do
      it 'should delay the welcome post until the user logs in' do
        token = Invite.generate_disposable_tokens(user).first

        expect do
          xhr :get, "/invites/redeem/#{token}",
            email: 'testing@gmail.com',
            username: 'somename',
            name: 'testing',
            password: 'asodaasdaosdhq'
        end.to change { User.count }.by(1)

        expect(Jobs::NarrativeInit.jobs.first["args"].first["user_id"]).to eq(User.last.id)
      end
    end
  end
end
