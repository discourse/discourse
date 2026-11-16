# frozen_string_literal: true

# Holds unsaved editor changes briefly so a page of the public blog can be
# rendered with them, without saving or activating anything.
class Blog::BlogTheme::CreateWorkingPreview
  include Service::Base

  STATIC_PAGE_PATHS = { "index" => "/", "archive" => "/archive", "about" => "/about" }.freeze
  PAGES = [*STATIC_PAGE_PATHS.keys, "not_found", "article"].freeze

  params(base_class: Blog::BlogTheme::AttributesContract) do
    attribute :page, :string
    attribute :article_id, :integer

    validates :page, inclusion: { in: PAGES }
    validates :article_id, presence: true, if: :article?

    def article?
      page == "article"
    end

    # The random path guarantees the blog renders its not-found page.
    def static_page_path
      return "/theme-preview-not-found-#{SecureRandom.hex(16)}" if page == "not_found"
      STATIC_PAGE_PATHS[page]
    end
  end

  policy :can_manage_themes
  model :preview_path
  model :preview_token, :store_working_copy

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def fetch_preview_path(params:)
    return params.static_page_path unless params.article?
    Blog::Publication.publicly_visible.find_by(id: params.article_id)&.path
  end

  def store_working_copy(params:, guardian:)
    Blog::ThemePreview.store_working_copy(params.theme_attributes, user: guardian.user)
  end
end
