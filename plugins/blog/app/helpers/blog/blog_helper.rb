# frozen_string_literal: true

module ::Blog
  module BlogHelper
    def blog_url(path = "")
      url = "#{Configuration.origin}#{path}"
      if @theme_preview_token
        url +=
          "#{path.include?("?") ? "&" : "?"}#{{ blog_theme_preview: @theme_preview_token }.to_query}"
      end
      url
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

    def blog_article_html(post)
      doc = Nokogiri::HTML5.fragment(post&.cooked.to_s)
      doc
        .css("[href], [src], [poster]")
        .each do |element|
          %w[href src poster].each do |attribute|
            value = element[attribute]
            next if value.blank? || value.start_with?("#")
            element[attribute] = (
              if attribute == "href"
                UrlHelper.absolute_without_cdn(value)
              else
                UrlHelper.absolute(value)
              end
            ) if value.start_with?("/") && !value.start_with?("//")
          end
        end
      doc
        .css("[srcset]")
        .each do |element|
          element["srcset"] = element["srcset"]
            .split(",")
            .map do |candidate|
              url, descriptor = candidate.strip.split(/\s+/, 2)
              url = UrlHelper.absolute(url) if url&.start_with?("/") && !url.start_with?("//")
              [url, descriptor].compact.join(" ")
            end
            .join(", ")
        end
      doc.css(".spoiler").each { |element| element["tabindex"] = "0" }
      doc.to_html.html_safe
    end

    def blog_date(date)
      I18n.l(date || Time.current, format: :date_only)
    end

    def blog_revision_tags(revision)
      Tag.visible(Guardian.new).where(name: revision.data["tags"])
    end

    def blog_revision_image(revision)
      url = revision&.data&.[]("image_url")
      UrlHelper.absolute(url) if url.present?
    end

    def blog_page_url(page)
      values = { page: page, q: @query.presence }.compact
      blog_url("#{request.path}?#{values.to_query}")
    end

    def blog_render_template(page, content: nil)
      assigns = blog_template_assigns
      assigns["content_html"] = TemplateRenderer::Html.new(content.to_s) if content
      TemplateRenderer.render(
        page,
        assigns,
        theme: blog_theme,
        custom: !@preview && !blog_customizations_disabled?,
        diagnostics: @theme_preview_token.present?,
      ).html_safe
    end

    def blog_template_assigns
      @blog_template_assigns ||= {
        "site" => {
          "title" => SiteSetting.blog_title,
          "description" => SiteSetting.blog_description,
          "url" => blog_url("/"),
          "archive_url" => blog_url("/archive"),
          "about_url" => blog_url("/about"),
          "feed_url" => blog_url("/feed.xml"),
          "community_url" => Discourse.base_url,
          "editor_url" => "#{Discourse.base_url}/blog/editor",
          "about_html" =>
            TemplateRenderer::Html.new(
              PrettyText.cook(SiteSetting.blog_about.presence || SiteSetting.blog_description),
            ),
        },
        "page" => {
          "title" => @page_title,
          "heading" =>
            (
              if @archive
                I18n.t("blog.archive")
              else
                @tag&.name || SiteSetting.blog_title
              end
            ),
          "eyebrow" =>
            (
              if @tag
                I18n.t("blog.tagged", tag: @tag.name)
              else
                I18n.t("blog.from_the_blog")
              end
            ),
          "archive" => !!@archive,
          "query" => @query,
          "preview_token" => @theme_preview_token,
          "previous_url" => @page && @page > 1 ? blog_page_url(@page - 1) : nil,
          "next_url" => @more ? blog_page_url(@page + 1) : nil,
        },
        "labels" => I18n.t("blog").select { |key, value| value.is_a?(String) }.stringify_keys,
        "articles" =>
          (@publications || []).each_with_index.map do |publication, index|
            blog_template_article(
              publication,
              publication.article,
              publication.discussion_topic,
              index: index,
            )
          end,
        "article" =>
          (
            if @article && @publication
              blog_template_article(@publication, @article, @topic, body: true)
            else
              nil
            end
          ),
      }
    end

    def blog_template_article(publication, article, topic, index: 0, body: false)
      date = publication.published_at
      values = {
        "title" => article.title,
        "url" => blog_url(publication.path),
        "excerpt" => publication.display_excerpt,
        "standfirst" => article.data["excerpt"].presence,
        "author" => article.data["author_name"],
        "published_at" => date&.iso8601,
        "date" => date && blog_date(date),
        "relative_date" =>
          date && I18n.t("blog.time_ago", time: distance_of_time_in_words(date, Time.current)),
        "reading_time" => I18n.t("blog.reading_time", count: article.reading_minutes),
        "featured" => publication.featured?,
        "image_url" => blog_revision_image(article),
        "discussion_url" => topic.url,
        "replies" => [topic.posts_count - 1, 0].max,
        "replies_label" => I18n.t("blog.replies", count: [topic.posts_count - 1, 0].max),
        "index" => format("%02d", index + 1),
        "updated_label" =>
          (
            if date && publication.article_updated_at.to_date > date.to_date
              I18n.t("blog.updated", date: blog_date(publication.article_updated_at))
            else
              nil
            end
          ),
      }
      if body
        values["body_html"] = TemplateRenderer::Html.new(blog_article_html(article))
        values["tags"] = blog_revision_tags(article).map do |tag|
          { "name" => tag.name, "url" => blog_url("/tag/#{tag.slug}") }
        end
      end
      values
    end

    def blog_article_schema
      {
        "@context" => "https://schema.org",
        "@type" => "BlogPosting",
        "headline" => @article.title,
        "description" => @description,
        "url" => @publication.url,
        "mainEntityOfPage" => @publication.url,
        "datePublished" => @publication.published_at&.iso8601,
        "dateModified" => @publication.article_updated_at&.iso8601,
        "author" => {
          "@type" => "Person",
          "name" => @article.data["author_name"],
        },
        "image" => blog_revision_image(@article),
      }.compact.to_json
    end
  end
end
