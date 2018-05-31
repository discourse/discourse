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

  describe "#penalty_history" do
    let(:moderator) { Fabricate(:moderator) }
    let(:logger) { StaffActionLogger.new(admin) }

    it "doesn't allow moderators to clear a user's history" do
      sign_in(moderator)
      delete "/admin/users/#{user.id}/penalty_history.json"
      expect(response.code).to eq("404")
    end

    def find_logs(action)
      UserHistory.where(target_user_id: user.id, action: UserHistory.actions[action])
    end

    it "allows admins to clear a user's history" do
      logger.log_user_suspend(user, "suspend reason")
      logger.log_user_unsuspend(user)
      logger.log_unsilence_user(user)
      logger.log_silence_user(user)

      sign_in(admin)
      delete "/admin/users/#{user.id}/penalty_history.json"
      expect(response.code).to eq("200")

      expect(find_logs(:suspend_user)).to be_blank
      expect(find_logs(:unsuspend_user)).to be_blank
      expect(find_logs(:silence_user)).to be_blank
      expect(find_logs(:unsilence_user)).to be_blank

      expect(find_logs(:removed_suspend_user)).to be_present
      expect(find_logs(:removed_unsuspend_user)).to be_present
      expect(find_logs(:removed_silence_user)).to be_present
      expect(find_logs(:removed_unsilence_user)).to be_present
    end

  end

end
