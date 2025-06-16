# frozen_string_literal: true

# Creates a new theme with the provided parameters. Themes can be created
# with various attributes including name, user selectability, color scheme,
# and theme fields.
#
# Also used to create theme components.
#
# The theme can optionally be set as the default theme, overriding SiteSetting.default_theme_id.
# The theme will then be used for all users on the site who haven't specifically set their
# theme preference.
#
# @example
#  Themes::Create.call(
#    guardian: guardian,
#    params: {
#      name: "My Theme",
#      user_selectable: true,
#      color_scheme_id: 1,
#      component: false,
#      theme_fields: [
#        { name: "header", target: "common", value: "content", type_id: 1 }
#      ],
#      default: false
#    }
#  )
#

class Themes::Create
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params String :name The name of the theme
  #   @option params Integer :user_id The ID of the user creating the theme
  #   @option params [Boolean] :user_selectable Whether the theme can be selected by users
  #   @option params [Integer] :color_scheme_id The ID of the color palette to use
  #   @option params [Boolean] :component Whether this is a theme component. These cannot be user_selectable or have a color_scheme_id
  #   @option params [Array] :theme_fields Array of theme field attributes
  #   @option params [Boolean] :default Whether to set this as the default theme
  #   @return [Service::Base::Context]

  params do
    attribute :name, :string
    attribute :user_id, :integer
    attribute :user_selectable, :boolean, default: false
    attribute :color_scheme_id, :integer
    attribute :component, :boolean, default: false
    attribute :theme_fields, :array
    attribute :default, :boolean, default: false

    validates :name, presence: true
    validates :user_id, presence: true
    validates :theme_fields, length: { maximum: 100 }
  end

  policy :ensure_remote_themes_are_not_allowlisted

  transaction do
    model :theme, :create_theme
    step :update_default_theme
    step :log_theme_change
  end

  private

  def ensure_remote_themes_are_not_allowlisted
    Theme.allowed_remote_theme_ids.nil?
  end

  def create_theme(params:)
    Theme.create(
      params.slice(:name, :user_id, :user_selectable, :color_scheme_id, :component),
    ) { |theme| params.theme_fields.to_a.each { |field| theme.set_field(**field.symbolize_keys) } }
  end

  def update_default_theme(params:, theme:)
    theme.set_default! if params.default
  end

  def log_theme_change(theme:, guardian:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
  end
end
