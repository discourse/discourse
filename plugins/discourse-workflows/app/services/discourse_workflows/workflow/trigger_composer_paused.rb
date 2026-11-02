# frozen_string_literal: true

module DiscourseWorkflows
  # Fires every composer paused trigger the draft matches, so the browser sends one request per
  # pause however many workflows it matched.
  class Workflow::TriggerComposerPaused
    include Service::Base

    MAX_DRAFT_KEY_LENGTH = 100

    params do
      attribute :draft_key, :string
      attribute :session_id, :string
      attribute :composer_action, :string
      attribute :title, :string
      attribute :raw, :string
      attribute :category_id, :integer
      attribute :topic_id, :integer
      attribute :reply_to_post_number, :integer

      validates :draft_key, presence: true, length: { maximum: MAX_DRAFT_KEY_LENGTH }
      validates :session_id,
                presence: true,
                length: {
                  maximum: ComposerSnapshot::MAX_SESSION_ID_LENGTH,
                }
      validates :composer_action, inclusion: { in: ComposerSnapshot::ACTIONS }
      validates :topic_id, presence: true, if: -> { composer_action == ComposerSnapshot::REPLY }
      validate :text_within_limits

      def text_within_limits
        errors.add(:title, :too_long) if title.to_s.length > SiteSetting.max_topic_title_length
        errors.add(:raw, :too_long) if raw.to_s.length > SiteSetting.max_post_length
      end
    end

    model :topic, optional: true
    model :snapshot
    step :fire_triggers

    private

    def fetch_topic(params:)
      ::Topic.find_by(id: params.topic_id) if params.composer_action == ComposerSnapshot::REPLY
    end

    def fetch_snapshot(params:, topic:, guardian:)
      ComposerSnapshot.new(
        user: guardian.user,
        action: params.composer_action,
        draft_key: params.draft_key,
        session_id: params.session_id,
        title: params.title,
        raw: params.raw,
        category_id: params.category_id,
        topic:,
        reply_to_post_number: params.reply_to_post_number,
      )
    end

    # The browser only asks after a match, but it is never trusted to have matched. Reopening the
    # composer starts a new session, so its phrases can fire again.
    def fire_triggers(params:, snapshot:, guardian:)
      fired_all =
        ComposerPausedDispatch.call(
          ComposerPausedDispatch.published_triggers(Nodes::ComposerPaused::V1::PAUSE),
          snapshot,
          "session:#{guardian.user.id}:#{params.draft_key}:#{params.session_id}",
        )

      # The browser asks again later for what didn't fire, and claims keep the rest from firing twice.
      fail!("rate limited") if !fired_all
    end
  end
end
