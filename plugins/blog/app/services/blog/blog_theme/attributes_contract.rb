# frozen_string_literal: true

# Bounds every editable theme field. Liquid syntax is checked only by services
# that save, because working previews render broken templates to show their
# diagnostics.
class Blog::BlogTheme::AttributesContract < Service::ContractBase
  HEX_COLOR = /\A\h{6}\z/

  attribute :name, :string
  Blog::BlogTheme::COLOR_FIELDS.each { |field| attribute field, :string }
  Blog::BlogTheme::CODE_FIELDS.each { |field| attribute field, :string }
  Blog::BlogTheme::TEMPLATE_FIELDS.each { |field| attribute field, :string, default: "" }

  validate :appearance_is_valid
  validate :templates_are_bounded

  def theme_attributes
    attributes.slice(*Blog::BlogTheme::FIELDS)
  end

  private

  def appearance_is_valid
    return if valid_name? && valid_colors? && valid_code?
    errors.add(:base, I18n.t("blog.themes.invalid"))
  end

  def templates_are_bounded
    return if bounded_templates?
    errors.add(:base, I18n.t("blog.themes.template_invalid"))
  end

  def valid_name?
    name.present? && name.length <= Blog::BlogTheme::MAX_NAME_LENGTH
  end

  def valid_colors?
    Blog::BlogTheme::COLOR_FIELDS.all? { |field| public_send(field)&.match?(HEX_COLOR) }
  end

  def valid_code?
    Blog::BlogTheme::CODE_FIELDS.all? do |field|
      bounded?(public_send(field), Blog::BlogTheme::MAX_CODE_BYTES)
    end
  end

  def bounded_templates?
    Blog::BlogTheme::TEMPLATE_FIELDS.all? do |field|
      bounded?(public_send(field), Blog::TemplateRenderer::MAX_TEMPLATE_BYTES)
    end
  end

  def bounded?(source, max_bytes)
    source.is_a?(String) && source.valid_encoding? && source.bytesize <= max_bytes
  end
end
