# frozen_string_literal: true

# Destroys multiple themes and logs the staff action. Related records are destroyed
# by ActiveRecord dependent: :destroy. Cannot be used to destroy system themes.
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
  #   @option params [array] :theme_ids The ids of the themes to destroy, must be positive integers.
  #   @return [service::base::context]

  params do
    attribute :theme_ids, :array
    validates :theme_ids, presence: true, length: { minimum: 1, maximum: 50 }
    validate :theme_ids_must_be_positive, if: -> { theme_ids.present? }

    before_validation { self.theme_ids = theme_ids.map(&:to_i).uniq if theme_ids.present? }

    def theme_ids_must_be_positive
      return if theme_ids.all?(&:positive?)
      errors.add(:theme_ids, I18n.t("errors.messages.must_all_be_positive"))
    end
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
