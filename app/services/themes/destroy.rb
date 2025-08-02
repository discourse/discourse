# frozen_string_literal: true

# Destroys a theme and logs the staff action. Related records are destroyed
# by ActiveRecord dependent: :destroy. Cannot be used to destroy system themes.
#
# @example
#  Themes::Destroy.call(
#    guardian: guardian,
#    params: {
#      id: theme.id,
#    }
#  )
#
class Themes::Destroy
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :id The ID of the theme to destroy, must be greater than 0.
  #   @return [Service::Base::Context]

  params do
    attribute :id, :integer

    # Negative theme IDs are for system themes only, which cannot be destroyed.
    validates :id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  end

  model :theme

  transaction do
    step :destroy_theme
    step :log_theme_destroy
  end

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.id)
  end

  def destroy_theme(theme:)
    theme.destroy
  end

  def log_theme_destroy(theme:, guardian:)
    StaffActionLogger.new(guardian.user).log_theme_destroy(theme)
  end
end
