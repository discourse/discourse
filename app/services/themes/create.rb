# frozen_string_literal: true

class Themes::Create
  include Service::Base

  policy :ban_in_allowlist_mode

  # Conditional policy for set_theme_fields ?
  # def ban_for_remote_theme!
  #   raise Discourse::InvalidAccess if @theme.remote_theme&.is_git?
  # end

  params do
    attribute :name, :string
    attribute :user_id, :integer
    attribute :user_selectable, :boolean, default: false
    attribute :color_scheme_id, :integer
    attribute :component, :boolean, default: false
    attribute :theme_fields, :array
    attribute :default, :boolean, default: false
  end

  step :initialize_theme
  step :set_theme_fields
  step :save_theme
  step :update_default_theme
  step :log_theme_change

  private

  def ban_in_allowlist_mode
    Theme.allowed_remote_theme_ids.present?
  end

  def initialize_theme(name:, user_id:, user_selectable:, color_scheme_id:, component:)
    context[:theme] = Theme.new(name:, user_id:, user_selectable:, color_scheme_id:, component:)
  end

  def set_theme_fields(theme_fields:, theme:)
    return if theme_fields.empty?

    theme_fields.each do |field|
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

  # Might need to be an Action
  def update_default_theme(default:, theme:)
    if theme.id == SiteSetting.default_theme_id && !default
      Theme.clear_default!
    elsif default
      theme.set_default!
    end
  end

  # Might need to be an Action
  def log_theme_change(theme:)
    StaffActionLogger.new(current_user).log_theme_change(nil, theme)
  end
end
