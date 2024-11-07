# frozen_string_literal: true

class Themes::Destroy
  include Service::Base

  params { attribute :id, :integer }

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
