# frozen_string_literal: true

require "digest"

module MarkdownEndpoint
  class TopicRenderer
    def initialize(topic_view, guardian:, post_number: nil)
      @topic_view = topic_view
      @topic = topic_view.topic
      @guardian = guardian
      @post_number = post_number&.to_i
    end

    def render
      posts = visible_posts
      raise Discourse::NotFound if single_post? && posts.empty?

      visible_post_count = single_post? ? visible_post_scope.count : posts.length
      buffer = String.new(header(visible_post_count))
      posts.each_with_index do |post, index|
        buffer << (index.zero? ? "\n\n" : "\n\n---\n\n")
        buffer << render_post(post)
      end
      buffer << "\n\n---\n\n_[View the full topic](#{@topic.url})._" if single_post?
      buffer << "\n"
    end

    private

    def visible_posts
      posts = visible_post_scope
      posts = posts.where(post_number: @post_number) if single_post?
      associations = [:user]
      associations << :localizations if SiteSetting.content_localization_enabled
      posts.preload(*associations).order(:sort_order).to_a
    end

    def visible_post_scope
      posts = @topic_view.filtered_posts
      posts = posts.where.not(post_type: Post.types[:whisper]) unless can_see_whispers?
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
      lines = ["# #{escape_text(title)}", "", "**URL:** #{@topic.url}"]
      lines << "**Category:** #{escape_text(@topic.category.name)}" if @topic.category
      tags = @topic_view.visible_tags.map(&:name)
      lines << "**Tags:** #{tags.map { |tag| escape_text(tag) }.join(", ")}" if tags.present?
      lines << "**Created:** #{@topic.created_at.iso8601}"
      lines << "**Posts:** #{visible_post_count}"
      lines << "**Showing post:** #{@post_number} of #{visible_post_count}" if single_post?
      lines.join("\n")
    end

    def render_post(post)
      serializer = BasicPostSerializer.new(post, scope: @guardian, root: false)
      serializer.topic_view = @topic_view
      cooked = serializer.cooked.to_s
      heading =
        "## Post #{post.post_number} by @#{escape_text(post.user&.username)} - #{post.created_at.iso8601}"
      "#{heading}\n\n#{cached_body(cooked)}"
    end

    def cached_body(cooked)
      context = [
        CookedProcessor::VERSION,
        Discourse.base_url,
        Discourse.asset_host,
        I18n.locale,
        cooked,
      ].join("\0")
      digest = Digest::SHA256.hexdigest(context)
      Discourse
        .cache
        .fetch("markdown-endpoint:cooked:#{digest}", expires_in: 1.week) do
          CookedProcessor.to_markdown(cooked)
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
