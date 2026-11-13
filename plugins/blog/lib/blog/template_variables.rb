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
      author: nil,
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
      @author = author
      @article = article
    end

    def to_h
      @to_h ||= {
        "site" => site,
        "page" => page,
        "labels" => I18n.t("blog").select { |_, value| value.is_a?(String) }.stringify_keys,
        "articles" =>
          @publications.each_with_index.map do |publication, index|
            ArticleVariables.new(
              publication,
              preview_token: @preview_token,
              co_author_users:,
            ).summary(index:)
          end,
        "article" => @article&.to_h,
      }
    end

    def description
      return SiteSetting.blog_description if description_cooked.blank?
      Nokogiri::HTML5.fragment(description_cooked).text.squish
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
        "eyebrow" => eyebrow,
        "description" => description,
        "description_html" => description_html,
        "author" => author,
        "archive" => @archive,
        "query" => @query,
        "preview_token" => @preview_token,
        "previous_url" => (page_url(@page - 1) if @page > 1),
        "next_url" => (page_url(@page + 1) if @more),
      }
    end

    def heading
      return I18n.t("blog.archive") if @archive
      return Revision.author_name(@author) if @author
      @tag&.name || SiteSetting.blog_title
    end

    def eyebrow
      return I18n.t("blog.tagged", tag: @tag.name) if @tag
      return I18n.t("blog.author") if @author
      I18n.t("blog.from_the_blog")
    end

    def author
      return if !@author
      {
        "name" => Revision.author_name(@author),
        "username" => @author.username,
        "url" => url(Revision.author_path(@author)),
        "avatar_url" => UrlHelper.absolute(@author.avatar_template.gsub("{size}", "240")),
        "bio_html" => (TemplateRenderer::Html.new(ArticleHtml.render(author_bio)) if author_bio),
      }
    end

    def description_html
      if description_cooked.present?
        TemplateRenderer::Html.new(ArticleHtml.render(description_cooked))
      elsif !@author && SiteSetting.blog_description.present?
        TemplateRenderer::Html.new("<p>#{ERB::Util.html_escape(SiteSetting.blog_description)}</p>")
      end
    end

    def description_cooked
      @tag&.description_cooked || author_bio
    end

    # Bylines are public, but a bio follows the profile's visibility. Public
    # profiles of inactive users show no bio either.
    def author_bio
      return if !@author&.active? || !Guardian.new.can_see_profile?(@author)
      @author.user_profile&.bio_cooked.presence
    end

    # One query for every card's co-authors.
    def co_author_users
      @co_author_users ||=
        User.where(id: @publications.flat_map { _1.article.co_author_ids }).index_by(&:id)
    end

    def page_url(number)
      url("#{@path}?#{{ page: number, q: @query.presence }.compact.to_query}")
    end

    def url(path)
      Configuration.url(path, preview_token: @preview_token)
    end
  end
end
