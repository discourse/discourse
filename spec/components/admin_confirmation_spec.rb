# frozen_string_literal: true

require 'admin_confirmation'
require 'rails_helper'

describe AdminConfirmation do

  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  describe "create_confirmation" do
    it "raises an error for non-admins" do
      ac = AdminConfirmation.new(user, Fabricate(:moderator))
      expect { ac.create_confirmation }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "email_confirmed!" do
    before do
      ac = AdminConfirmation.new(user, admin)
      ac.create_confirmation
      @token = ac.token
    end

    it "cannot confirm if the user loses admin access" do
      ac = AdminConfirmation.find_by_code(@token)
      ac.performed_by.update_column(:admin, false)
      expect { ac.email_confirmed! }.to raise_error(Discourse::InvalidAccess)
    end

    it "can confirm admin accounts" do
      ac = AdminConfirmation.find_by_code(@token)
      expect(ac.performed_by).to eq(admin)
      expect(ac.target_user).to eq(user)
      expect(ac.token).to eq(@token)
      Jobs.expects(:enqueue).with(:send_system_message, user_id: user.id, message_type: 'welcome_staff', message_options: { role: :admin })
      ac.email_confirmed!

      user.reload
      expect(user.admin?).to eq(true)

      # It creates a staff log
      logs = UserHistory.where(
        action: UserHistory.actions[:grant_admin],
        target_user_id: user.id
      )
      expect(logs).to be_present

      # It removes the redis keys for another user
      expect(AdminConfirmation.find_by_code(ac.token)).to eq(nil)
      expect(AdminConfirmation.exists_for?(user.id)).to eq(false)
    end

  end

end
