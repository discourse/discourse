# frozen_string_literal: true

module MarkdownEndpoint
  class TopicListRenderer
    def initialize(
      topics:,
      title:,
      url:,
      page:,
      next_page_url: nil,
      previous_page_url: nil,
      user: nil
    )
      @topics = topics.to_a
      @title = title
      @url = url
      @page = page.to_i
      @next_page_url = next_page_url
      @previous_page_url = previous_page_url
      @timestamp = Timestamp.new(user)
      preload_users
    end

    def render
      buffer = String.new(header)
      @topics.each do |topic|
        buffer << "\n\n---\n\n"
        buffer << render_topic(topic)
      end
      {
        "previous_page" => @previous_page_url,
        "next_page" => @next_page_url,
      }.each { |label, target| buffer << "\n\n#{page_link(label, target)}" if target.present? }
      buffer << "\n"
    end

    private

    def page_link(label, target)
      url = URI(@url)
      query = Rack::Utils.parse_nested_query(url.query).except("page")
      query.merge!(
        Rack::Utils.parse_nested_query(URI(target).query).slice(
          *ControllerSupport::SAFE_QUERY_PARAMETERS,
        ),
      )
      url.query = query.to_query.presence
      "[#{I18n.t("markdown_endpoints.#{label}")}](#{url})"
    end

    def preload_users
      ActiveRecord::Associations::Preloader.new(records: @topics, associations: :user).call
    end

    def header
      lines = ["# #{escape_text(@title)}", "", "**URL:** #{@url}"]
      lines.concat(["", DirectoryRenderer.navigation])
      lines.concat(["", "**Page:** #{@page + 1}"]) if @page.positive?
      lines.join("\n")
    end

    def render_topic(topic)
      lines = ["## [#{escape_text(topic.title)}](#{topic.url})"]
      lines.concat(["", '<div class="topic-metadata">', ""])
      metadata = []
      if topic.user
        metadata << "**Author:** [@#{escape_text(topic.user.username)}](#{topic.user.full_url})"
      end
      metadata << "**#{I18n.t("markdown_endpoints.replies")}:** #{[topic.posts_count - 1, 0].max}"
      if topic.last_posted_at
        metadata << "**#{I18n.t("markdown_endpoints.last_updated")}:** #{@timestamp.render(topic.last_posted_at, url: topic.url)}"
      end
      lines << metadata.join("\\\n")
      lines.concat(["", "</div>"])
      excerpt = Nokogiri::HTML5.fragment(topic.excerpt.to_s).text.squish
      lines.concat(["", escape_text(excerpt)]) if excerpt.present?
      lines.join("\n")
    end

    def escape_text(text)
      text
        .to_s
        .gsub(/[\\`*_\[\]<>]/) { |character| "\\#{character}" }
        .sub(/\A[#>-]/) { |character| "\\#{character}" }
    end
  end
end
