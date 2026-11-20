# frozen_string_literal: true

# Saves a new, inactive theme draft.
class Blog::BlogTheme::Create
  include Service::Base

  params(base_class: Blog::BlogTheme::AttributesContract) do
    validate :templates_compile

    private

    def templates_compile
      Blog::BlogTheme::TEMPLATE_FIELDS.each do |field|
        source = public_send(field)
        next unless bounded?(source, Blog::TemplateRenderer::MAX_TEMPLATE_BYTES)
        next unless (error = Blog::TemplateRenderer.syntax_error(source))
        page = field.delete_prefix("template_")
        errors.add(:base, I18n.t("blog.themes.template_parse_error", error: "#{page}: #{error}"))
      end
    end
  end

  # Provenance of a Git import, set by ImportRepository rather than by request params.
  options { attribute :source }

  policy :can_manage_themes

  lock do
    transaction do
      policy :within_theme_limit, class_name: Blog::BlogTheme::Policy::WithinThemeLimit
      model :theme, :create_theme
      step :log_save
    end
  end

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def create_theme(params:, options:)
    Blog::BlogTheme.create(params.theme_attributes, source: options.source)
  end

  def log_save(guardian:, theme:)
    Blog::BlogTheme::Action::LogStaffAction.call(actor: guardian.user, theme:, event: "save")
  end
end
