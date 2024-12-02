# frozen_string_literal: true

class Experiments::Toggle
  include Service::Base

  policy :current_user_is_admin

  params do
    attribute :setting_name, :string
    validates :setting_name, presence: true
  end

  policy :setting_is_available
  transaction { step :toggle }

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
  end

  def toggle(params:, guardian:)
    SiteSetting.set_and_log(
      params.setting_name,
      !SiteSetting.public_send(params.setting_name),
      guardian.user,
    )
  end
end
