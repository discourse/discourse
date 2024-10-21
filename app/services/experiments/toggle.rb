# frozen_string_literal: true

class Experiments::Toggle
  include Service::Base

  policy :current_user_is_admin

  contract do
    attribute :setting_name, :string
    validates :setting_name, presence: true
  end

  policy :setting_is_available

  transaction { step :toggle }

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(contract:)
    SiteSetting.respond_to?(contract.setting_name)
  end

  def toggle(contract:, guardian:)
    SiteSetting.set_and_log(
      contract.setting_name,
      !SiteSetting.send(contract.setting_name),
      guardian.user,
    )
  end
end
