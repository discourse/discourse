# frozen_string_literal: true

module ::Blog
  class TemplateVariables
    def initialize(
      title: nil,
      preview_token: nil,
      path: "/",
      publications: [],
      page: 1,
      more: false,
      query: nil,
      archive: false,
      tag: nil,
      article: nil
    )
      @title = title
      @preview_token = preview_token
      @path = path
      @publications = publications
      @page = page
      @more = more
      @query = query
      @archive = archive
      @tag = tag
      @article = article
    end

    def to_h
      @to_h ||= {
        "site" => site,
        "page" => page,
        "labels" => I18n.t("blog").select { |_, value| value.is_a?(String) }.stringify_keys,
        "articles" =>
          @publications.each_with_index.map do |publication, index|
            ArticleVariables.new(publication, preview_token: @preview_token).summary(index:)
          end,
        "article" => @article&.to_h,
      }
    end

    def description
      return SiteSetting.blog_description if tag_description_cooked.blank?
      Nokogiri::HTML5.fragment(tag_description_cooked).text.squish
    end

    private

    def site
      {
        "title" => SiteSetting.blog_title,
        "description" => SiteSetting.blog_description,
        "url" => url("/"),
        "archive_url" => url("/archive"),
        "about_url" => url("/about"),
        "feed_url" => url("/feed.xml"),
        "community_url" => Discourse.base_url,
        "editor_url" => "#{Discourse.base_url}/blog-editor",
        "about_html" =>
          TemplateRenderer::Html.new(
            PrettyText.cook(SiteSetting.blog_about.presence || SiteSetting.blog_description),
          ),
      }
    end

    def page
      {
        "title" => @title,
        "heading" => heading,
        "eyebrow" => @tag ? I18n.t("blog.tagged", tag: @tag.name) : I18n.t("blog.from_the_blog"),
        "description" => description,
        "description_html" => description_html,
        "archive" => @archive,
        "query" => @query,
        "preview_token" => @preview_token,
        "previous_url" => (page_url(@page - 1) if @page > 1),
        "next_url" => (page_url(@page + 1) if @more),
      }
    end

    def heading
      return I18n.t("blog.archive") if @archive
      @tag&.name || SiteSetting.blog_title
    end

    def description_html
      if tag_description_cooked.present?
        TemplateRenderer::Html.new(ArticleHtml.render(tag_description_cooked))
      elsif SiteSetting.blog_description.present?
        TemplateRenderer::Html.new("<p>#{ERB::Util.html_escape(SiteSetting.blog_description)}</p>")
      end
    end

    def tag_description_cooked
      @tag&.description_cooked
    end

    def page_url(number)
      url("#{@path}?#{{ page: number, q: @query.presence }.compact.to_query}")
    end

    def url(path)
      Configuration.url(path, preview_token: @preview_token)
    end
  end
end
