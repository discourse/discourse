# frozen_string_literal: true

module ::Blog
  # Reference material for the theme editor: the built-in templates, the public
  # articles a preview can use, and the variables templates receive.
  class ThemeAuthoringSerializer < ApplicationSerializer
    attributes :templates, :articles, :has_page, :variables

    def templates
      TemplateRenderer::PAGES.to_h { |page| ["template_#{page}", TemplateRenderer.builtin(page)] }
    end

    def articles
      ActiveModel::ArraySerializer.new(
        object,
        each_serializer: SampleArticleSerializer,
        scope:,
        root: false,
      ).as_json
    end

    # Pages have no sample picker; the preview uses the newest one.
    def has_page
      Publication.publicly_visible.pages.exists?
    end

    def variables
      @options[:variables]
    end
  end
end
