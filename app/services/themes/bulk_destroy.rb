# frozen_string_literal: true

# Destroys multiple themes and logs the staff action. Related records are destroyed
# by ActiveRecord dependent: :destroy.
#
# @example
#  Themes::Destroy.call(
#    guardian: guardian,
#    params: {
#      theme_ids: [theme_1.id, theme_2.id],
#    }
#  )
#
class Themes::BulkDestroy
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [guardian] guardian
  #   @param [hash] params
  #   @option params [array] :theme_ids The ids of the themes to destroy
  #   @return [service::base::context]

  params do
    attribute :theme_ids, :array
    validates :theme_ids, presence: true, length: { minimum: 1, maximum: 50 }
  end

  model :themes

  transaction do
    step :log_themes_destroy
    step :destroy_themes
  end

  private

  def fetch_themes(params:)
    Theme.where(id: params.theme_ids)
  end

  def log_themes_destroy(themes:, guardian:)
    staff_action_logger = StaffActionLogger.new(guardian.user)
    themes.each { |theme| staff_action_logger.log_theme_destroy(theme) }
  end

  def destroy_themes(themes:)
    themes.destroy_all
  end
end
