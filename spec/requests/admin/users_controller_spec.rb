require 'rails_helper'

RSpec.describe Admin::UsersController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  describe '#disable_second_factor' do
    let(:second_factor) { user.create_totp }

    describe 'as an admin' do
      before do
        sign_in(admin)
        second_factor
        expect(user.reload.user_second_factor).to eq(second_factor)
      end

      it 'should able to disable the second factor for another user' do
        SiteSetting.queue_jobs = true

        expect do
          put "/admin/users/#{user.id}/disable_second_factor.json"
        end.to change { Jobs::CriticalUserEmail.jobs.length }.by(1)

        expect(response.status).to eq(200)
        expect(user.reload.user_second_factor).to eq(nil)

        job_args = Jobs::CriticalUserEmail.jobs.first["args"].first

        expect(job_args["user_id"]).to eq(user.id)
        expect(job_args["type"]).to eq('account_second_factor_disabled')
      end

      it 'should not be able to disable the second factor for the current user' do
        put "/admin/users/#{admin.id}/disable_second_factor.json"

        expect(response.status).to eq(403)
      end

      describe 'when user does not have second factor enabled' do
        it 'should raise the right error' do
          user.user_second_factor.destroy!

          put "/admin/users/#{user.id}/disable_second_factor.json"

          expect(response.status).to eq(400)
        end
      end
    end
  end
end
