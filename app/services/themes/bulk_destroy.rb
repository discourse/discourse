# frozen_string_literal: true

class Themes::BulkDestroy
  include Service::Base

  params do
    attribute :theme_ids, :array
    validates :theme_ids, presence: true
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
    themes.each { |theme| StaffActionLogger.new(guardian.user).log_theme_destroy(theme) }
  end

  def destroy_themes(themes:)
    themes.destroy_all
  end
end
