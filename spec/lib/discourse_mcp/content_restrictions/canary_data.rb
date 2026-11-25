# frozen_string_literal: true

require "base64"
require "json"

module McpContentCanaries
  FIXTURES = JSON.parse(File.read(File.join(__dir__, "canary_fixtures.json"))).freeze
  CONFIGURATIONS = %w[pm_off allowlist denied_category denied_tag combined pm_off_and_forum].freeze
  MISSING_ID = 99_999_999

  class CanaryData
    attr_reader :posts,
                :tokens,
                :related,
                :values,
                :allowed_post,
                :configuration,
                :conversation_reviewable

    def initialize(admin, configuration)
      @admin = admin
      @configuration = configuration
      @posts = {}
      @tokens = {}
      @related = {}
      @serial = 0
      @existing_category_ids = Category.all.to_a.map(&:id)
      @allowed = add_category(:allowed)
      @outside = add_category(:outside, id: 91_000_001)
      @denied = add_category(:denied, id: 91_000_002)
      @child = add_category(:denied_child, parent_category: @denied, id: 91_000_003)
      @definition = add_category(:definition, definition: false, id: 91_000_004)
      @outside_empty = add_category(:excluded_empty, definition: false, id: 91_000_008)
      @selected_child = add_category(:selected_child, parent_category: @outside, id: 91_000_009)
      empty_category = add_category(:allowed_empty, definition: false, parent_category: @allowed)
      @categories = Category.all.to_a
      @allowed_category_ids = [@allowed.id, empty_category.id, @selected_child.id]
      @tag = Fabricate(:tag, name: "legal-hold", id: 91_000_005)
      @recipient = Fabricate(:user, refresh_auto_groups: true)
      @invitee = Fabricate(:user, refresh_auto_groups: true)
      @author = Fabricate(:user, refresh_auto_groups: true)
      @allowed_post =
        Fabricate(
          :post,
          user: admin,
          topic: Fabricate(:topic, user: admin, category: @selected_child),
          raw: "cru2needle allowed public evidence",
        )
      if defined?(DiscourseTopicVoting::CategorySetting)
        DiscourseTopicVoting::CategorySetting.create!(category: @selected_child)
        Category.reset_voting_cache
      end
      reply = Fabricate(:post, user: @recipient, topic: allowed_post.topic)
      group = Fabricate(:group, public_admission: true, public_exit: true)
      group.add(@author)
      group.add(admin)
      @request_group = Fabricate(:group)
      @request_group.add_owner(admin)
      @request_group.update!(allow_membership_requests: true)
      @requester = Fabricate(:user, refresh_auto_groups: true)
      hook = Fabricate(:web_hook, active: false)
      theme = Fabricate(:theme)
      theme.set_field(target: :settings, name: :yaml, value: "cr_u2_fixture: 1")
      theme.set_field(target: :translations, name: :en, value: "en:\n  cr_u2_label: Original label")
      theme.save!
      tag_group = Fabricate(:tag_group)
      moderation_user = Fabricate(:user, refresh_auto_groups: true)
      inactive_user = Fabricate(:user, active: false)
      add_post(:outside_allowlist, category: @outside)
      add_post(:denied_subcategory, category: @child)
      indexed = add_post(:tagged_after_index, category: @allowed)
      SearchIndexer.index(indexed, force: true)
      indexed.topic.tags << @tag
      add_post(:private_message, private_message: true)
      definition_post = add_post(:tagged_definition, category: @definition)
      @definition.update_column(:topic_id, definition_post.topic_id)
      definition_post.topic.tags << @tag
      add_post(
        :restricted_author,
        user: @author,
        category: @denied,
        private_message: private_messages_off?,
      )
      @posts[:restricted_author].topic.tags << @tag
      request_post = add_post(:membership_request, user: @requester, private_message: true)
      request_post.topic.update!(
        title:
          I18n.t(
            "groups.request_membership_pm.title",
            group_name: @request_group.name,
            locale: @requester.effective_locale,
          ),
      )
      TopicAllowedUser.find_or_create_by!(topic: request_post.topic, user: admin)
      Fabricate(
        :group_request,
        user: @requester,
        group: @request_group,
        reason: tokens.fetch(:membership_request),
      )
      request_post.topic.tags << @tag
      request_post.topic.custom_fields["requested_group_id"] = @request_group.id
      request_post.topic.save_custom_fields
      conversation_post = add_post(:reviewable_conversation, private_message: true)
      conversation_post.topic.tags << @tag
      @conversation_reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: allowed_post,
          topic: allowed_post.topic,
          target_created_by: admin,
        )
      @conversation_reviewable.reviewable_scores.first.update!(
        meta_topic: conversation_post.topic,
        status: :pending,
      )
      @crawl_target =
        add_post(:redirect_target, category: @denied, private_message: private_messages_off?)
      @crawl_target.topic.tags << @tag
      @posts.each { |name, post| add_related(name, post, hook) }
      Fabricate(:post_revision, post: allowed_post, user: admin)
      allowed_post.update_columns(version: 2, public_version: 2)
      valid_reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: reply,
          topic: reply.topic,
          target_created_by: admin,
        )
      Fabricate(
        :draft,
        user: admin,
        topic: allowed_post.topic,
        draft_key: "topic_#{allowed_post.topic_id}",
        sequence: 0,
        data: { reply: "Fresh allowed draft", action: "reply" }.to_json,
      )
      @values = {
        "topic_id" => allowed_post.topic_id,
        "post_id" => allowed_post.id,
        "reply_id" => reply.id,
        "pm_id" => @posts[:private_message].topic_id,
        "category_id" => @allowed.id,
        "empty_category_id" => empty_category.id,
        "empty_category_name" => empty_category.name,
        "topic_uri" => "discourse://topic/#{allowed_post.topic_id}",
        "post_uri" => "discourse://post/#{allowed_post.id}",
        "draft_key" => "topic_#{allowed_post.topic_id}",
        "reviewable_id" => valid_reviewable.id,
        "group_id" => group.id,
        "group_name" => group.name,
        "request_group_id" => @request_group.id,
        "request_group_name" => @request_group.name,
        "requester_username" => @requester.username,
        "admin_username" => admin.username,
        "recipient_username" => @recipient.username,
        "invitee_username" => @invitee.username,
        "invitee_email" => @invitee.email,
        "restricted_author_username" => @author.username,
        "moderation_username" => moderation_user.username,
        "inactive_username" => inactive_user.username,
        "webhook_id" => hook.id,
        "event_id" => @related.values.first.fetch(:webhook_event).id,
        "fingerprint" => hook.destination_fingerprint,
        "theme_id" => theme.id,
        "theme_name" => theme.name,
        "theme_revision" => DiscourseMcp::Tools::ThemeSupport.code_revision(theme),
        "tag_group_id" => tag_group.id,
        "tag_group_name" => tag_group.name,
        "site_title" => SiteSetting.title,
        "password" => "Fresh-#{SecureRandom.hex(20)}-A1!",
        "upload_data" => Base64.strict_encode64("Fresh upload #{SecureRandom.hex(30)}"),
      }
      if defined?(DiscourseDataExplorer::Query)
        @values["query_id"] = DiscourseDataExplorer::Query.create!(
          name: "Fresh query",
          sql: "SELECT 1",
          user: admin,
        ).id
      end
      @values["channel_id"] = Fabricate(:category_channel, chatable: @allowed).id if defined?(
        Chat::Channel
      )
      Tag.update_topic_counts
    end

    def resolve(value)
      case value
      when Hash
        value.transform_values { |child| resolve(child) }
      when Array
        value.map { |child| resolve(child) }
      when String
        return theme_archive if value == "$theme_archive"
        return Fabricate(:theme_with_remote_url).id if value == "$remote_theme_id"
        value.start_with?("$") ? values.fetch(value.delete_prefix("$")) : value
      else
        value
      end
    end

    def theme_archive
      require "theme_store/zip_exporter"

      exporter = ThemeStore::ZipExporter.new(Theme.find(values.fetch("theme_id")))
      Base64.strict_encode64(File.binread(exporter.package_filename))
    ensure
      exporter&.cleanup!
    end

    def private_messages_off?
      %w[pm_off pm_off_and_forum].include?(configuration)
    end

    def install_rule!
      McpContentRule.create!(rule_kind: "private_messages", config: {}) if private_messages_off?
      if configuration != "pm_off"
        McpContentRule.create!(rule_kind: "forum_content", config: forum_config)
      end
    end

    def forum_config
      {
        allow: {
          mode: configuration == "allowlist" ? "selected" : "all",
          category_ids: configuration == "allowlist" ? [@allowed.id, @selected_child.id] : [],
          tag_ids: [],
        },
        deny: {
          category_ids:
            (
              if %w[denied_category combined pm_off_and_forum].include?(configuration)
                [@denied.id]
              else
                []
              end
            ),
          tag_ids:
            %w[denied_tag combined pm_off_and_forum].include?(configuration) ? [@tag.id] : [],
        },
      }
    end

    def restricted_posts
      @restricted_posts ||=
        posts.values.select do |post|
          if configuration == "pm_off"
            post.topic.private_message?
          else
            config = forum_config
            denied_category =
              config[:deny][:category_ids].include?(post.topic.category_id) ||
                (
                  post.topic.category_id == @child.id &&
                    config[:deny][:category_ids].include?(@denied.id)
                )
            denied_tag = config[:deny][:tag_ids].present? && post.topic.tags.exists?(id: @tag.id)
            excluded =
              config[:allow][:mode] == "selected" && !post.topic.private_message? &&
                !@allowed_category_ids.include?(post.topic.category_id)
            (private_messages_off? && post.topic.private_message?) || denied_category ||
              denied_tag || excluded
          end
        end
    end

    def restricted_tokens
      posts.filter_map { |name, post| tokens.fetch(name) if restricted_posts.include?(post) }
    end

    def restricted_categories
      case configuration
      when "pm_off"
        []
      when "allowlist"
        @categories.reject { |category| @allowed_category_ids.include?(category.id) }
      when "denied_category"
        [@denied, @child]
      when "denied_tag"
        [@definition]
      when "combined", "pm_off_and_forum"
        [@denied, @child, @definition]
      end
    end

    def restricted_category_text
      restricted_categories
        .flat_map { |category| [category.name, category.slug, category.description].compact_blank }
        .uniq
    end

    def contextual_category_ids
      restricted_categories.map(&:id) & @existing_category_ids
    end

    def restricted_ids
      ids =
        restricted_posts.flat_map do |post|
          [post.id, post.topic_id, related.fetch(posts.key(post)).fetch(:upload).id]
        end
      if configuration != "pm_off"
        ids.concat(targets("category").map(&:first))
        ids << @tag.id if %w[denied_tag combined pm_off_and_forum].include?(configuration)
      end
      ids.uniq
    end

    def restricted_urls
      restricted_posts.flat_map do |post|
        upload = related.fetch(posts.key(post)).fetch(:upload)
        [
          upload.url,
          upload.short_url,
          URI.join(Discourse.base_url, upload.url).to_s,
          post.full_url,
          post.url,
          post.topic.url,
          post.topic.relative_url,
          "discourse://topic/#{post.topic_id}",
          "discourse://post/#{post.id}",
        ]
      end
    end

    def targets(kind)
      case kind
      when "topic", "draft", "topic_uri"
        restricted_posts
          .map(&:topic_id)
          .uniq
          .map do |id|
            case kind
            when "draft"
              ["topic_#{id}", "topic_#{MISSING_ID}"]
            when "topic_uri"
              ["discourse://topic/#{id}", "discourse://topic/#{MISSING_ID}"]
            else
              [id, MISSING_ID]
            end
          end
      when "post", "posts", "post_uri"
        restricted_posts.map do |post|
          case kind
          when "posts"
            [[post.id], [MISSING_ID]]
          when "post_uri"
            ["discourse://post/#{post.id}", "discourse://post/#{MISSING_ID}"]
          else
            [post.id, MISSING_ID]
          end
        end
      when "category", "categories"
        restricted_categories.map do |category|
          kind == "categories" ? [[category.id], [MISSING_ID]] : [category.id, MISSING_ID]
        end
      when "tag", "tags"
        if %w[denied_tag combined pm_off_and_forum].include?(configuration)
          kind == "tag" ? [[@tag.id, MISSING_ID]] : [[[@tag.id], [MISSING_ID]]]
        else
          []
        end
      when "reviewable"
        posts.filter_map do |name, post|
          [related.fetch(name).fetch(:reviewable).id, MISSING_ID] if restricted_posts.include?(post)
        end
      when "upload"
        restricted_posts.map do |post|
          name = posts.key(post)
          [related.fetch(name).fetch(:upload).id, MISSING_ID]
        end
      else
        raise "Unclassified target #{kind}"
      end
    end

    def redirect_target
      @crawl_target
    end

    private

    def add_category(label, definition: true, **attributes)
      marker = "cru2 #{label.to_s.tr("_", " ")} #{SecureRandom.hex(6)}"
      Fabricate(
        definition ? :category_with_definition : :category,
        user: @admin,
        name: marker,
        description: "Description for #{marker}",
        **attributes,
      )
    end

    def next_token(name)
      @tokens[name] = "cru2 #{name.to_s.tr("_", " ")} #{SecureRandom.hex(6)}"
    end

    def add_post(name, user: @admin, category: @allowed, private_message: false)
      token = next_token(name)
      @serial += 1
      topic =
        if private_message
          Fabricate(
            :private_message_topic,
            id: 92_000_000 + @serial,
            user:,
            recipient: @recipient,
            title: "cru2needle #{token}",
          )
        else
          Fabricate(
            :topic,
            id: 92_000_000 + @serial,
            user:,
            category:,
            title: "cru2needle #{token}",
          )
        end
      @posts[name] = Fabricate(
        :post,
        id: 93_000_000 + @serial,
        user:,
        topic:,
        raw: "cru2needle confidential #{token}",
      )
    end

    def add_related(name, post, hook)
      token = tokens.fetch(name)
      notification =
        Fabricate(
          :notification,
          user: @admin,
          post:,
          data: {
            topic_title: token,
            original_post_id: post.id,
            original_username: post.user.username,
          }.to_json,
        )
      action =
        Fabricate(
          :user_action,
          user: @admin,
          acting_user: post.user,
          action_type: UserAction::REPLY,
          target_topic: post.topic,
          target_post: post,
        )
      bookmark = Fabricate(:bookmark, user: @admin, bookmarkable: post, name: token)
      draft =
        Fabricate(
          :draft,
          user: @admin,
          topic: post.topic,
          draft_key: "topic_#{post.topic_id}",
          sequence: 0,
          data: {
            reply: token,
            title: token,
            action: post.topic.private_message? ? "privateMessage" : "reply",
          }.to_json,
        )
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: post,
          topic: post.topic,
          category: post.topic.category,
          target_created_by: post.user,
        )
      revision =
        Fabricate(
          :post_revision,
          post:,
          user: post.user,
          modifications: {
            raw: ["Old #{token}", post.raw],
            cooked: ["<p>#{token}</p>", post.cooked],
          },
        )
      post.update_columns(version: 2, public_version: 2)
      badge =
        Fabricate(
          :user_badge,
          user: @admin,
          granted_by: @admin,
          post:,
          is_favorite: true,
          badge: Fabricate(:badge, enabled: true, show_posts: true),
        )
      event =
        Fabricate(
          :web_hook_event,
          web_hook: hook,
          payload: {
            post: {
              id: post.id,
              topic_id: post.topic_id,
              raw: post.raw,
              title: token,
              url: post.full_url,
            },
          }.to_json,
        )
      upload =
        Fabricate(
          :upload,
          id: 94_000_000 + @related.length,
          original_filename: "#{token}.txt",
          user: @admin,
        )
      UploadReference.create!(upload:, target: post)
      @related[name] = {
        notification:,
        action:,
        bookmark:,
        draft:,
        reviewable:,
        revision:,
        badge:,
        webhook_event: event,
        upload:,
      }
    end
  end
end
