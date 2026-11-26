# frozen_string_literal: true

module ::Blog
  # Reference material for the theme editor: the built-in templates, the public
  # articles a preview can use, the variables templates receive, and the tags
  # and filters they may use.
  class ThemeAuthoringSerializer < ApplicationSerializer
    attributes :templates, :articles, :has_page, :variables, :tags, :filters

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

    def tags
      TemplateRenderer::ENVIRONMENT.tags.keys.sort
    end

    def filters
      TemplateRenderer::ENVIRONMENT.filter_method_names.sort
    end
  end
end
