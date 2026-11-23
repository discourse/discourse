# frozen_string_literal: true

# Publishing to a blog nobody can read would put its discussion in public
# before the article.
class Blog::Publication::Policy::BlogPublished < Service::PolicyBase
  delegate :publication, to: :context, private: true

  def call
    publication.blog.published?
  end

  def reason
    I18n.t("blog.errors.blog_unpublished", name: publication.blog.name)
  end
end
