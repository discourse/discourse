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

  policy :ban_in_allowlist_mode

  step :initialize_theme

  policy :ban_for_remote_theme

  step :set_theme_fields

  transaction do
    step :save_theme
    step :update_default_theme
    step :log_theme_change
  end

  private

  def ban_in_allowlist_mode
    Theme.allowed_remote_theme_ids.nil?
  end

  def initialize_theme(params:)
    context[:theme] = Theme.new(
      name: params.name,
      user_id: params.user_id,
      user_selectable: params.user_selectable,
      color_scheme_id: params.color_scheme_id,
      component: params.component,
    )
  end

  def ban_for_remote_theme(params:, theme:)
    return true if params.theme_fields.blank?
    !theme.remote_theme&.is_git?
  end

  def set_theme_fields(params:, theme:)
    return if params.theme_fields.blank?

    params.theme_fields.each do |field|
      theme.set_field(
        target: field[:target],
        name: field[:name],
        value: field[:value],
        type_id: field[:type_id],
        upload_id: field[:upload_id],
      )
    end
  end

  # TODO (martin) Ask loic about this, the old theme controller expected the
  # errors from the theme model save to be shown to the user.
  def save_theme(theme:)
    theme.save!
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
