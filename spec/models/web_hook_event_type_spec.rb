# frozen_string_literal: true

RSpec.describe WebHookEventType do
  describe "#active" do
    it "returns only active types" do
      core_event_types = WebHookEventType.active.map(&:name)
      expect(core_event_types).to match_array(
        %w[
          topic_created
          topic_revised
          topic_edited
          topic_destroyed
          topic_recovered
          post_created
          post_edited
          post_destroyed
          post_recovered
          user_logged_in
          user_logged_out
          user_confirmed_email
          user_created
          user_approved
          user_updated
          user_destroyed
          user_suspended
          user_unsuspended
          group_created
          group_updated
          group_destroyed
          category_created
          category_updated
          category_destroyed
          tag_created
          tag_updated
          tag_destroyed
          reviewable_created
          reviewable_updated
          notification_created
          user_badge_granted
          user_badge_revoked
          user_added_to_group
          user_removed_from_group
          post_liked
          user_promoted
        ],
      )

      SiteSetting.stubs(:solved_enabled).returns(true)
      SiteSetting.stubs(:assign_enabled).returns(true)
      SiteSetting.stubs(:topic_voting_enabled).returns(true)
      SiteSetting.stubs(:chat_enabled).returns(true)
      SiteSetting.stubs(:enable_category_experts).returns(true)
      plugins_event_types = WebHookEventType.active.map(&:name) - core_event_types
      expect(plugins_event_types).to match_array(
        %w[
          accepted_solution
          unaccepted_solution
          assigned
          unassigned
          topic_upvote
          topic_unvote
          chat_message_created
          chat_message_edited
          chat_message_trashed
          chat_message_restored
          category_experts_approved
          category_experts_unapproved
        ],
      )
    end
  end
end
