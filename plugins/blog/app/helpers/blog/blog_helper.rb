# frozen_string_literal: true

module ::Blog
  module BlogHelper
    def blog_url(path = "")
      Configuration.url(path, preview_token: @theme_preview_token)
    end

    def blog_theme
      @blog_theme ||= BlogTheme.active
    end

    def blog_customizations_disabled?
      params[:blog_safe_mode] == "1"
    end

    def blog_theme_asset_url(path = "/blog-theme.css")
      query = {}
      query[:blog_safe_mode] = "1" if blog_customizations_disabled?
      query[:blog_theme_snapshot] = blog_theme["snapshot"] if !@theme_preview_token &&
        blog_theme["snapshot"]
      suffix = query.present? ? "?#{query.to_query}" : ""
      blog_url("#{path}#{suffix}")
    end

    def blog_render_template(page, content: nil)
      variables = @template_variables.to_h
      if content
        variables = variables.merge("content_html" => TemplateRenderer::Html.new(content.to_s))
      end
      TemplateRenderer.render(
        page,
        variables,
        theme: blog_theme,
        custom: !@preview && !blog_customizations_disabled?,
        diagnostics: @theme_preview_token.present?,
      ).html_safe
    end
  end
end
