# frozen_string_literal: true

module DiscourseBoosts
  class ReviewableBoost < Reviewable
    include ReviewableActionBuilder

    def serializer
      DiscourseBoosts::ReviewableBoostSerializer
    end

    def self.action_aliases
      {
        agree_and_keep_hidden: :agree_and_delete,
        agree_and_silence: :agree_and_delete,
        agree_and_suspend: :agree_and_delete,
        delete_and_agree: :agree_and_delete,
      }
    end

    def boost
      @boost ||= (target || DiscourseBoosts::Boost.find_by(id: target_id))
    end

    def boost_creator
      @boost_creator ||= boost&.user
    end

    def flagged_by_user_ids
      @flagged_by_user_ids ||= reviewable_scores.map(&:user_id)
    end

    def post
      nil
    end

    def build_combined_actions(actions, guardian, args)
      return unless pending?
      return build_action(actions, :ignore, icon: "up-right-from-square") if boost.blank?

      agree =
        actions.add_bundle(
          "#{id}-agree",
          icon: "thumbs-up",
          label: "reviewables.actions.agree.title",
        )

      build_action(actions, :agree_and_delete, icon: "trash-can", bundle: agree)
      build_action(actions, :agree_and_keep_boost, icon: "far-eye", bundle: agree)

      if guardian.can_suspend?(boost_creator)
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

      disagree_bundle =
        actions.add_bundle(
          "#{id}-disagree",
          icon: "far-eye",
          label: "reviewables.actions.disagree_bundle.title",
        )

      build_action(actions, :disagree, icon: "far-eye", bundle: disagree_bundle)
      build_action(actions, :ignore, icon: "xmark", bundle: disagree_bundle)
      build_action(actions, :delete_and_agree, icon: "trash-can", bundle: disagree_bundle)
    end

    def perform_agree_and_keep_boost(performed_by, args)
      agree
    end

    def perform_agree_and_delete(performed_by, args)
      agree do
        if boost
          DiscourseBoosts::Boost.publish_remove(boost.post, boost.id)
          boost.destroy!
        end
      end
    end

    def perform_disagree(performed_by, args)
      disagree
    end

    def perform_ignore(performed_by, args)
      ignore
    end

    def perform_delete_and_ignore(performed_by, args)
      ignore do
        if boost
          DiscourseBoosts::Boost.publish_remove(boost.post, boost.id)
          boost.destroy!
        end
      end
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
