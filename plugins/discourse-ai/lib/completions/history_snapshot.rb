# frozen_string_literal: true

module DiscourseAi
  module Completions
    class HistorySnapshot
      VERSION = 2

      def self.post(post, guardian:, bot_usernames:, capture_metadata: true)
        new(:post, post, guardian, bot_usernames, capture_metadata: capture_metadata)
      end

      def self.chat(message, guardian:, bot_user_ids:)
        new(:chat, message, guardian, bot_user_ids)
      end

      def initialize(kind, source, guardian, bots, capture_metadata: true)
        @kind = kind
        @source = source
        @thread_id = source.thread_id if kind == :chat
        @guardian = guardian
        @bots = bots
        @metadata = metadata_for(source.id) if capture_metadata
        @evidence_scope = {
          "user_id" => @guardian.user&.id,
          "authorization" => authorization_scope,
        }
      end

      def metadata
        @metadata ||= metadata_for(@source.id)
      end

      def verify!
        @authorization_scope = nil
        @single_reader = nil
        if !matches_metadata?(@metadata, metadata_for(@source.id))
          raise ContextPreparation::Error.new("history_changed")
        end
      end

      def validate_checkpoint!(metadata)
        if !metadata.is_a?(Hash) || metadata["version"] != VERSION ||
             metadata["kind"] != @kind.to_s || !metadata["source_id"].is_a?(Integer)
          return false
        end
        @checkpoint_validations ||= {}
        key = metadata.to_json
        return @checkpoint_validations[key] if @checkpoint_validations.key?(key)
        @checkpoint_validations[key] = matches_metadata?(
          metadata,
          metadata_for(metadata["source_id"]),
        )
      rescue ContextPreparation::Error
        false
      end

      def evidence_scope
        @evidence_scope
      end

      def authorized_evidence?(entries, requester_id: nil)
        Array(entries).present? && filter_evidence(entries, requester_id: requester_id) == entries
      end

      def filter_evidence(entries, requester_id: nil)
        legacy_allowed = (requester_id.nil? || requester_id == @guardian.user&.id) && single_reader?
        Array(entries).select do |entry|
          entry[7] ? permitted_evidence_scope?(entry[7]) : legacy_allowed
        end
      end

      def user_turn_count
        return 1 if @kind == :post && !@source.topic.private_message?
        return 1 if @kind == :chat && !@source.chat_channel.direct_message_channel?

        relation = source_relation(@source.id, full: true)
        if @kind == :post
          relation.joins(:user).where.not(users: { username: @bots }).count
        else
          relation.where.not(user_id: @bots).count
        end
      end

      def stamp!(raw_context)
        checkpoint =
          raw_context.find do |entry|
            entry.is_a?(Array) && entry[2] == "user" && entry[1].blank? &&
              entry[0].to_s.start_with?(PromptMessagesBuilder::COMPRESSED_CONTEXT_PREFIX)
          end
        verify!
        raw_context.each { |entry| entry[7] = evidence_scope }
        checkpoint[6] ||= metadata if checkpoint
      end

      def covered_position(checkpoint_metadata)
        if @kind == :post
          @source.topic.posts.find(checkpoint_metadata["source_id"]).post_number
        else
          checkpoint_metadata["source_id"]
        end
      end

      private

      def matches_metadata?(previous, current)
        return false if !previous.is_a?(Hash)
        keys = %w[version kind source_id user_id]
        return false if previous.slice(*keys) != current.slice(*keys)
        if previous["rows_digest"]
          previous["rows_digest"] == current["rows_digest"] &&
            permitted_evidence_scope?(
              { "user_id" => previous["user_id"], "authorization" => previous["authorization"] },
            ) && permitted_membership?(previous["membership"], current["membership"])
        else
          previous["digest"] == current["digest"]
        end
      end

      def permitted_membership?(previous, current)
        return previous.nil? && current.nil? if previous.nil? || current.nil?
        return false if !previous.is_a?(Array) || !current.is_a?(Array)
        if @kind == :post
          previous.length == 2 && current.length == 2 &&
            previous
              .zip(current)
              .all? do |before, after|
                before.is_a?(Array) && after.is_a?(Array) && (before - after).empty?
              end
        else
          (previous - current).empty?
        end
      end

      def permitted_evidence_scope?(provenance)
        return false if !provenance.is_a?(Hash) || provenance["user_id"] != @guardian.user&.id
        if provenance == { "user_id" => @guardian.user&.id, "authorization" => authorization_scope }
          return true
        end
        previous = provenance["authorization"]
        current = authorization_scope
        return false if !previous.is_a?(Array) || previous.length != 4
        previous_groups, previous_trust, previous_staff, previous_permissions = previous
        return false if !previous_groups.is_a?(Array) || !previous_permissions.is_a?(Array)
        if previous_permissions.any? { |row| !row.is_a?(Array) || !row.first.is_a?(Integer) }
          return false
        end
        if (previous_groups - current[0]).present? || previous_trust.to_i > current[1].to_i
          return false
        end
        return false if previous_staff && !current[2]
        previous_categories = previous_permissions.map(&:first).uniq
        current_categories = current[3].map(&:first).uniq
        (previous_categories - current_categories).empty?
      end

      def metadata_for(source_id)
        visible =
          (
            if @kind == :post
              @guardian.can_see?(@source.topic)
            else
              @guardian.can_preview_chat_channel?(@source.chat_channel)
            end
          )
        raise ContextPreparation::Error.new("history_changed") if !visible
        relation = source_relation(source_id)
        rows =
          if @kind == :post
            relation
              .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
              .order("posts.id")
              .pluck(
                "posts.id",
                "posts.user_id",
                "posts.post_type",
                Arel.sql("md5(posts.raw)"),
                Arel.sql(
                  "(SELECT md5(string_agg(ref.upload_id::text, ',' ORDER BY ref.upload_id)) FROM upload_references ref WHERE ref.target_type = 'Post' AND ref.target_id = posts.id)",
                ),
                Arel.sql("md5(post_custom_prompts.custom_prompt::text)"),
              )
          else
            relation
              .joins(
                "LEFT JOIN chat_message_custom_prompts ON chat_message_custom_prompts.message_id = chat_messages.id",
              )
              .order("chat_messages.id")
              .pluck(
                "chat_messages.id",
                Arel.sql("md5(chat_messages.message)"),
                Arel.sql("md5(chat_messages.blocks::text)"),
                Arel.sql(
                  "(SELECT md5(string_agg(ref.upload_id::text, ',' ORDER BY ref.upload_id)) FROM upload_references ref WHERE ref.target_type = 'Chat::Message' AND ref.target_id = chat_messages.id)",
                ),
                "chat_messages.user_id",
                "chat_messages.deleted_at",
                Arel.sql("md5(chat_message_custom_prompts.custom_prompt::text)"),
              )
          end
        {
          "version" => VERSION,
          "kind" => @kind.to_s,
          "source_id" => source_id,
          "user_id" => @guardian.user&.id,
          "rows_digest" => Digest::SHA256.hexdigest(rows.to_json),
          "authorization" => authorization_scope,
          "membership" => membership_scope,
          "digest" =>
            Digest::SHA256.hexdigest([rows, authorization_scope, membership_scope].to_json),
        }
      end

      def single_reader?
        return @single_reader unless @single_reader.nil?
        @single_reader =
          if @kind == :post
            @source.topic.private_message? && !@source.topic.allowed_groups.exists? &&
              @source.topic.allowed_users.where.not(username: @bots).pluck(:id) ==
                [@guardian.user&.id]
          else
            @source.chat_channel.direct_message_channel? &&
              (@source.chat_channel.allowed_user_ids - @bots) == [@guardian.user&.id]
          end
      end

      def authorization_scope
        return @authorization_scope if @authorization_scope
        user = @guardian.user
        group_ids = user&.group_users&.order(:group_id)&.pluck(:group_id) || []
        @authorization_scope = [
          group_ids,
          user&.trust_level,
          user&.staff?,
          CategoryGroup
            .where(group_id: group_ids + [Group::AUTO_GROUPS[:everyone]])
            .order(:category_id, :group_id)
            .pluck(:category_id, :group_id, :permission_type),
        ]
      end

      def membership_scope
        if @kind == :post && @source.topic.private_message?
          [
            @source.topic.allowed_users.where.not(username: @bots).order(:id).pluck(:id),
            @source.topic.allowed_groups.order(:id).pluck(:id),
          ]
        elsif @kind == :chat && @source.chat_channel.direct_message_channel?
          @source.chat_channel.allowed_user_ids.sort
        end
      end

      def source_relation(source_id, full: false)
        if @kind == :post
          source = @source.topic.posts.find_by(id: source_id)
          if !source || source.post_number > @source.post_number
            raise ContextPreparation::Error.new("invalid_checkpoint")
          end
          types = [Post.types[:regular]]
          types << Post.types[:whisper] if @source.post_type == Post.types[:whisper]
          relation =
            @guardian.filter_hidden_posts(
              @source
                .topic
                .posts
                .where("post_number <= ?", source.post_number)
                .where(post_type: types),
              category: @source.topic.category,
            )
          if !full && !@source.topic.private_message?
            relation =
              relation.where(
                id:
                  relation
                    .reorder(post_number: :desc)
                    .limit(PromptMessagesBuilder::PUBLIC_CONTEXT_MESSAGES)
                    .select(:id),
              )
          end
          relation
        else
          source = Chat::Message.find_by(id: source_id, chat_channel_id: @source.chat_channel_id)
          if !source || source.id > @source.id
            raise ContextPreparation::Error.new("invalid_checkpoint")
          end
          relation =
            Chat::Message.where(chat_channel_id: @source.chat_channel_id).where(
              "chat_messages.id <= ?",
              source.id,
            )
          if @thread_id
            if source.thread_id != @thread_id
              raise ContextPreparation::Error.new("invalid_checkpoint")
            end
            relation.where(thread_id: @thread_id)
          elsif @source.chat_channel.direct_message_channel?
            relation
          else
            relation =
              relation.joins(
                "LEFT JOIN chat_threads ON chat_threads.id = chat_messages.thread_id",
              ).where(
                "chat_messages.thread_id IS NULL OR chat_threads.original_message_id = chat_messages.id",
              )
            if !full
              relation =
                relation.where(
                  id:
                    relation
                      .reorder(id: :desc)
                      .limit(PromptMessagesBuilder::PUBLIC_CONTEXT_MESSAGES)
                      .select(:id),
                )
            end
            relation
          end
        end
      end
    end
  end
end
