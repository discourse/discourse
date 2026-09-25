# frozen_string_literal: true

require "digest"

module MarkdownEndpoint
  class TopicRenderer
    def initialize(topic_view, guardian:, post_number: nil, query: {})
      @topic_view = topic_view
      @topic = topic_view.topic
      @guardian = guardian
      @post_number = post_number&.to_i
      @query = query
      @timestamp = Timestamp.new(guardian.user)
    end

    def render
      posts = visible_posts
      raise Discourse::NotFound if single_post? && posts.empty?

      buffer = String.new(header(posts.length))
      posts.each_with_index do |post, index|
        buffer << (index.zero? ? "\n\n" : "\n\n---\n\n")
        buffer << render_post(post)
      end
      buffer << "\n\n---\n\n_[View the full topic](#{@topic.url})._" if single_post?
      unless single_post?
        {
          "previous_page" => @topic_view.prev_page,
          "next_page" => @topic_view.next_page,
        }.each do |label, page|
          next unless page

          query = @query.merge("page" => page).to_query
          buffer << "\n\n[#{I18n.t("markdown_endpoints.#{label}")}](#{@topic.url}.md?#{query})"
        end
      end
      buffer << "\n"
    end

    private

    def visible_posts
      posts = @topic_view.posts.to_a
      posts = posts.select { |post| post.post_number == @post_number } if single_post?
      posts =
        posts.reject { |post| post.post_type == Post.types[:whisper] } unless can_see_whispers?
      posts
    end

    def single_post?
      @post_number.present?
    end

    def can_see_whispers?
      user = @guardian.user
      allowed_group_ids = SiteSetting.whispers_allowed_groups_map
      user && allowed_group_ids.present? && user.group_users.exists?(group_id: allowed_group_ids)
    end

    def header(visible_post_count)
      title = ContentLocalization.translated_topic_title(@topic, @guardian) || @topic.title
      lines = ["# #{escape_text(EmojiConverter.convert(title))}", "", "**URL:** #{@topic.url}"]
      lines << "**Category:** #{escape_text(@topic.category.name)}" if @topic.category
      tags = @topic_view.visible_tags.map(&:name)
      lines << "**Tags:** #{tags.map { |tag| escape_text(tag) }.join(", ")}" if tags.present?
      lines << "**Created:** #{@timestamp.render(@topic.created_at, url: @topic.url)}"
      lines << "**Posts on this page:** #{visible_post_count}"
      lines << "**Page:** #{@topic_view.page}" unless single_post?
      lines << "**Showing post:** #{@post_number}" if single_post?
      lines.join("\n")
    end

    def render_post(post)
      serializer = BasicPostSerializer.new(post, scope: @guardian, root: false)
      serializer.topic_view = @topic_view
      cooked = serializer.cooked.to_s
      lines = ['<div class="post-metadata">', ""]
      if post.user
        avatar_url = UrlHelper.absolute(post.user.avatar_template.gsub("{size}", "32"))
        avatar_url = "#{Discourse.base_protocol}:#{avatar_url}" if avatar_url.start_with?("//")
        avatar_url = URI::DEFAULT_PARSER.escape(avatar_url, /[^\x21-\x7E]|[<>"()\\]/)
        author = escape_text(post.user.username)
        author_link = "![#{author}](#{avatar_url}) [@#{author}](#{post.user.full_url})"
        lines << "### #{I18n.t("markdown_endpoints.post_author", author: author_link)}"
      end
      lines << "#### #{I18n.t("markdown_endpoints.post_date", timestamp: @timestamp.render(post.created_at, url: post.full_url))}"
      lines.concat(["", "</div>", ""])
      lines << cached_body(cooked, post_url: post.full_url)
      lines.join("\n")
    end

    def cached_body(cooked, post_url:)
      context = [
        CookedProcessor::VERSION,
        Discourse.base_url,
        Discourse.asset_host,
        I18n.locale,
        post_url,
        cooked,
      ].join("\0")
      digest = Digest::SHA256.hexdigest(context)
      Discourse
        .cache
        .fetch("markdown-endpoint:cooked:#{digest}", expires_in: 1.week) do
          CookedProcessor.to_markdown(cooked, post_url:)
        end
    end

    def escape_text(text)
      text
        .to_s
        .gsub(/[\\`*_\[\]<>]/) { |character| "\\#{character}" }
        .sub(/\A[#>-]/) { |character| "\\#{character}" }
    end
  end
end
