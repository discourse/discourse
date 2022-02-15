# frozen_string_literal: true

require 'rails_helper'

describe SecondFactor::Actions::GrantAdmin do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  after do
    AdminConfirmation.cleanup_redis
  end

  def params(hash)
    ActionController::Parameters.new(hash)
  end

  def create_instance(user)
    SecondFactor::Actions::GrantAdmin.new(user, Guardian.new(user))
  end

  describe "#no_second_factors_enabled!" do
    it "sends new admin confirmation email" do
      instance = create_instance(admin)
      expect {
        instance.no_second_factors_enabled!(params({ user_id: user.id }))
      }.to change { AdminConfirmation.exists_for?(user.id) }.from(false).to(true)
    end

    it "ensures the acting user is admin" do
      instance = create_instance(user)
      expect {
        instance.no_second_factors_enabled!(params({ user_id: user.id }))
      }.to raise_error(Discourse::InvalidAccess)
      expect(AdminConfirmation.exists_for?(user.id)).to eq(false)
    end
  end

  describe "#second_factor_auth_required!" do
    it "returns a hash with callback_params and redirect_path" do
      instance = create_instance(admin)
      hash = instance.second_factor_auth_required!(params({ user_id: user.id }))
      expect(hash[:callback_params]).to eq({ user_id: user.id })
      expect(hash[:redirect_path]).to eq("/admin/users/#{user.id}/#{user.username}")
    end

    it "ensures the acting user is admin" do
      instance = create_instance(user)
      expect {
        instance.second_factor_auth_required!(params({ user_id: user.id }))
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "#second_factor_auth_completed!" do
    it "grants the target user admin access and logs to staff action logs" do
      instance = create_instance(admin)
      expect {
        instance.second_factor_auth_completed!(user_id: user.id)
      }.to change { user.reload.admin }.from(false).to(true)
      expect(UserHistory.exists?(
        acting_user_id: admin.id,
        target_user_id: user.id,
        action: UserHistory.actions[:grant_admin]
      )).to eq(true)
    end

    it "ensures the acting user is admin" do
      instance = create_instance(user)
      expect {
        instance.second_factor_auth_completed!(user_id: user.id)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
