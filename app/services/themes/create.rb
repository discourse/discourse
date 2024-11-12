# frozen_string_literal: true

class Themes::Create
  include Service::Base

  params do
    attribute :name, :string
    attribute :user_id, :integer
    attribute :user_selectable, :boolean, default: false
    attribute :color_scheme_id, :integer
    attribute :component, :boolean, default: false
    attribute :theme_fields, :array
    attribute :default, :boolean, default: false
  end

  policy :ensure_remote_themes_are_not_allowlisted
  model :theme, :instantiate_theme
  step :set_theme_fields

  transaction do
    step :save_theme
    step :update_default_theme
    step :log_theme_change
  end

  private

  def ensure_remote_themes_are_not_allowlisted
    Theme.allowed_remote_theme_ids.nil?
  end

  def instantiate_theme(params:)
    context[:theme] = Theme.new(
      params.slice(:name, :user_id, :user_selectable, :color_scheme_id, :component),
    )
  end

  def set_theme_fields(params:, theme:)
    return if params.theme_fields.blank?

    params.theme_fields.each do |field|
      begin
        theme.set_field(**field.symbolize_keys)
      rescue Theme::InvalidFieldTargetError, Theme::InvalidFieldTypeError => err
        fail!(err.message)
      end
    end
  end

  def save_theme(theme:)
    theme.save

    if theme.errors.any?
      fail!("Could not save theme with errors #{theme.errors.full_messages.join(",")}")
    end
  end

  # TODO (martin) Might need to be an Action, it's used in other theme related things too.
  def update_default_theme(params:, theme:)
    if theme.default? && !params.default
      Theme.clear_default!
    elsif params.default
      theme.set_default!
    end
  end

  # TODO (martin): Might need to be an Action, it is used in other theme related things too.
  def log_theme_change(theme:, guardian:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
  end
end
