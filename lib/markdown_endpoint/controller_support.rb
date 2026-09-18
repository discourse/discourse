# frozen_string_literal: true

module MarkdownEndpoint
  module ControllerSupport
    extend ActiveSupport::Concern

    SAFE_QUERY_PARAMETERS = %w[
      ascending
      before
      bumped_before
      category
      exclude_tag
      f
      filter
      filter_top_level_replies
      filter_upwards_post_id
      group_name
      include_subcategories
      match_all_tags
      max_posts
      min_posts
      no_subcategories
      no_tags
      order
      page
      parent_category_id
      per_page
      period
      post_number
      print
      q
      replies_to_post_number
      search
      show_deleted
      state
      status
      subset
      tag
      tags
      topic_ids
      username_filters
    ].freeze

    included do
      before_action :normalize_markdown_format
      after_action :add_markdown_discovery_header
      helper_method :markdown_alternate_link_tag, :markdown_alternate_url
    end

    def markdown_alternate_url
      return unless SiteSetting.experimental_markdown_endpoints

      path = markdown_alternate_path
      return if path.blank?

      query = request.query_parameters.slice(*SAFE_QUERY_PARAMETERS)
      url = "#{Discourse.base_url_no_prefix}#{path}"
      query.present? ? "#{url}?#{query.to_query}" : url
    end

    def markdown_alternate_link_tag
      return if request.format.md?

      url = markdown_alternate_url
      return if url.blank?

      helpers.tag.link(rel: "alternate", type: "text/markdown", href: url)
    end

    def render_markdown(body)
      merge_vary_accept
      render plain: body, content_type: "text/markdown; charset=utf-8"
    end

    private

    def normalize_markdown_format
      return unless request.format.md?
      return if request.path.end_with?(".md")

      accept = request.headers["Accept"]
      if SiteSetting.experimental_markdown_endpoints && markdown_supported_response? &&
           AcceptHeader.preferred?(accept)
        return
      end

      html_quality = AcceptHeader.quality(accept, "text", "html")
      json_quality = AcceptHeader.quality(accept, "application", "json")
      request.formats = [json_quality > html_quality ? :json : :html]
    end

    def add_markdown_discovery_header
      return unless response.status.between?(200, 299)
      return unless response.media_type == "text/html"
      return if markdown_alternate_url.blank?

      value = %(<#{markdown_alternate_url}>; rel="alternate"; type="text/markdown")
      response.headers["Link"] = [response.headers["Link"], value].compact.join(", ")
      merge_vary_accept
    end

    def merge_vary_accept
      tokens = response.headers["Vary"].to_s.split(",").map(&:strip).reject(&:blank?)
      tokens << "Accept" unless tokens.any? { |token| token.casecmp?("Accept") }
      response.headers["Vary"] = tokens.join(", ")
    end

    def markdown_supported_response?
      markdown_alternate_path.present?
    end

    def markdown_alternate_path
      app_path = request.path.delete_prefix(Discourse.base_path)
      return "#{Discourse.base_path}/latest.md" if app_path.blank? || app_path == "/"
      return if app_path.end_with?(".json")
      route_path = app_path.delete_suffix(".md")

      supported =
        case controller_name
        when "topics"
          %w[show feed].include?(action_name) &&
            route_path.match?(%r{\A/t/(?:[^/]+/)?\d+(?:/\d+)?(?:\.rss)?\z})
        when "list"
          route_path.match?(%r{\A/(?:latest|hot|top)(?:\.rss)?\z}) ||
            route_path.match?(%r{\A/c/.+/\d+(?:\.rss)?\z})
        when "tags"
          (action_name == "index" && route_path == "/tags") ||
            (
              %w[show tag_feed].include?(action_name) &&
                route_path.match?(%r{\A/tag/[^/]+(?:/\d+)?(?:\.rss)?\z})
            )
        when "categories"
          action_name == "index" && route_path == "/categories"
        else
          false
        end
      return unless supported

      "#{Discourse.base_path}#{route_path.delete_suffix(".rss").chomp("/")}.md"
    end
  end
end
