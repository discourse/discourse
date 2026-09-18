# frozen_string_literal: true

module MarkdownEndpoint
  class TopicListRenderer
    def initialize(topics:, title:, url:, page:)
      @topics = topics.to_a
      @title = title
      @url = url
      @page = page.to_i
      preload_users
    end

    def render
      buffer = String.new(header)
      @topics.each do |topic|
        buffer << "\n\n---\n\n"
        buffer << render_topic(topic)
      end
      buffer << "\n"
    end

    private

    def preload_users
      ActiveRecord::Associations::Preloader.new(records: @topics, associations: :user).call
    end

    def header
      lines = ["# #{escape_text(@title)}", "", "**URL:** #{@url}"]
      lines << "**Page:** #{@page + 1}" if @page.positive?
      lines << "**Topics on this page:** #{@topics.length}"
      lines.join("\n")
    end

    def render_topic(topic)
      lines = ["## [#{escape_text(topic.title)}](#{topic.url})"]
      lines << ""
      lines << "**Author:** @#{escape_text(topic.user.username)}" if topic.user
      lines << "**Last posted:** #{topic.last_posted_at.iso8601}" if topic.last_posted_at
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
