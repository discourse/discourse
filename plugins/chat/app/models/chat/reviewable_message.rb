# frozen_string_literal: true

module Chat
  class ReviewableMessage < Reviewable
    include ReviewableActionBuilder

    validates :type, length: { maximum: 100 }
    validates :target_type, length: { maximum: 100 }

    def serializer
      Chat::ReviewableMessageSerializer
    end

    def self.action_aliases
      {
        agree_and_keep_hidden: :agree_and_delete,
        agree_and_silence: :agree_and_delete,
        agree_and_suspend: :agree_and_delete,
        delete_and_agree: :agree_and_delete,
      }
    end

    def self.score_to_silence_user
      sensitivity_score(SiteSetting.chat_silence_user_sensitivity, scale: 0.6)
    end

    def chat_message
      @chat_message ||= (target || Chat::Message.with_deleted.find_by(id: target_id))
    end

    def chat_message_creator
      @chat_message_creator ||= chat_message.user
    end

    def flagged_by_user_ids
      @flagged_by_user_ids ||= reviewable_scores.map(&:user_id)
    end

    def post
      nil
    end

    # TODO (reviewable-refresh): Remove this method when fully migrated to new UI
    def build_legacy_combined_actions(actions, guardian, args)
      return unless pending?

      return build_action(actions, :ignore, icon: "up-right-from-square") if chat_message.blank?

      agree =
        actions.add_bundle(
          "#{id}-agree",
          icon: "thumbs-up",
          label: "reviewables.actions.agree.title",
        )

      if chat_message.deleted_at?
        build_action(actions, :agree_and_restore, icon: "far-eye", bundle: agree)
        build_action(actions, :agree_and_keep_deleted, icon: "thumbs-up", bundle: agree)
        build_action(actions, :disagree_and_restore, icon: "thumbs-down")
      else
        build_action(actions, :agree_and_delete, icon: "far-eye-slash", bundle: agree)
        build_action(actions, :agree_and_keep_message, icon: "thumbs-up", bundle: agree)
        build_action(actions, :disagree, icon: "thumbs-down")
      end

      if guardian.can_suspend?(chat_message_creator)
        build_action(
          actions,
          :agree_and_suspend,
          icon: "ban",
          bundle: agree,
          client_action: "suspend",
        )
        build_action(
          actions,
          :agree_and_silence,
          icon: "microphone-slash",
          bundle: agree,
          client_action: "silence",
        )
      end

      ignore_bundle = actions.add_bundle("#{id}-ignore", label: "reviewables.actions.ignore.title")

      build_action(actions, :ignore, icon: "up-right-from-square", bundle: ignore_bundle)

      unless chat_message.deleted_at?
        build_action(actions, :delete_and_agree, icon: "trash-can", bundle: ignore_bundle)
      end
    end

    # TODO (reviewable-refresh): Merge this method into build_actions when fully migrated to new UI
    def build_new_separated_actions
      bundle_actions = { no_action_message: {} }
      if chat_message.deleted_at?
        bundle_actions[:restore_message] = {}
      else
        bundle_actions[:delete_message] = {}
      end
      build_bundle(
        "#{id}-message-actions",
        "chat.reviewables.actions.message_actions.bundle_title",
        bundle_actions,
      )

      build_user_actions_bundle
    end

    # TODO (reviewable-refresh): Remove combined actions below when fully migrated to new UI
    def perform_agree_and_keep_message(performed_by, args)
      agree
    end

    def perform_agree_and_restore(performed_by, args)
      agree { chat_message.recover! }
    end

    def perform_agree_and_delete(performed_by, args)
      agree { chat_message.trash!(performed_by) }
    end

    def perform_disagree_and_restore(performed_by, args)
      disagree { chat_message.recover! }
    end

    def perform_disagree(performed_by, args)
      disagree
    end

    def perform_ignore(performed_by, args)
      ignore
    end

    def perform_delete_and_ignore(performed_by, args)
      ignore { chat_message.trash!(performed_by) }
    end

    def perform_agree_and_keep_deleted(performed_by, args)
      agree
    end
    # TODO (reviewable-refresh): Remove combined actions above when fully migrated to new UI

    def perform_no_action_message(performed_by, args)
      if chat_message.deleted_at?
        create_result(:success, :approved, [created_by_id], true)
      else
        create_result(:success, :rejected, [created_by_id], true)
      end
    end

    def perform_restore_message(_performed_by, args)
      chat_message.recover!
      create_result(:success, :rejected, [created_by_id], true)
    end

    def perform_delete_message(performed_by, args)
      chat_message.trash!(performed_by)
      create_result(:success, :approved, [created_by_id], true)
    end

    private

    def agree
      yield if block_given?
      create_result(:success, :approved) do |result|
        result.update_flag_stats = { status: :agreed, user_ids: flagged_by_user_ids }
        result.recalculate_score = true
      end
    end

    def disagree
      yield if block_given?

      UserSilencer.unsilence(chat_message_creator)

      create_result(:success, :rejected) do |result|
        result.update_flag_stats = { status: :disagreed, user_ids: flagged_by_user_ids }
        result.recalculate_score = true
      end
    end

    def ignore
      yield if block_given?
      create_result(:success, :ignored) do |result|
        result.update_flag_stats = { status: :ignored, user_ids: flagged_by_user_ids }
      end
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#  type_source             :string           default("unknown"), not null
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
