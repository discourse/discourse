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

  transaction do
    try(Theme::InvalidFieldTargetError, Theme::InvalidFieldTypeError) do
      model :theme, :create_theme
    end
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

  def create_theme(params:)
    Theme.create(
      params.slice(:name, :user_id, :user_selectable, :color_scheme_id, :component),
    ) { |theme| params.theme_fields.to_a.each { |field| theme.set_field(**field.symbolize_keys) } }
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
