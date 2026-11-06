# frozen_string_literal: true

module ::Blog
  # Reference material for the theme editor: the built-in templates, the public
  # articles a preview can use, and the variables templates receive.
  class ThemeAuthoringSerializer < ApplicationSerializer
    attributes :templates, :variables
    has_many :articles, serializer: SampleArticleSerializer, embed: :objects

    def templates
      TemplateRenderer::PAGES.to_h { |page| ["template_#{page}", TemplateRenderer.builtin(page)] }
    end

    def articles
      object
    end

    def variables
      @options[:variables]
    end
  end
end
