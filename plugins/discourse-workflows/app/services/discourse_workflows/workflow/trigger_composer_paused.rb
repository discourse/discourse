# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::TriggerComposerPaused
    include Service::Base

    MAX_DRAFT_KEY_LENGTH = 100
    MAX_SESSION_ID_LENGTH = 64

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string
      attribute :draft_key, :string
      attribute :session_id, :string
      attribute :composer_action, :string
      attribute :title, :string
      attribute :raw, :string
      attribute :category_id, :integer
      attribute :topic_id, :integer
      attribute :reply_to_post_number, :integer

      validates :workflow_id, presence: true
      validates :trigger_node_id, presence: true
      validates :draft_key, presence: true, length: { maximum: MAX_DRAFT_KEY_LENGTH }
      validates :session_id, presence: true, length: { maximum: MAX_SESSION_ID_LENGTH }
      validates :composer_action, inclusion: { in: ComposerSnapshot::ACTIONS }
      validates :topic_id, presence: true, if: -> { composer_action == ComposerSnapshot::REPLY }
      validate :text_within_limits

      def text_within_limits
        errors.add(:title, :too_long) if title.to_s.length > SiteSetting.max_topic_title_length
        errors.add(:raw, :too_long) if raw.to_s.length > SiteSetting.max_post_length
      end
    end

    model :published_trigger
    model :topic, optional: true
    model :snapshot
    policy :can_fire_trigger
    model :matched_phrases, optional: true
    policy :matches_phrases
    model :new_phrases, optional: true
    policy :has_new_phrases
    step :enqueue_workflow

    private

    # Pauses are frequent, so this reads the cached published triggers instead of the database.
    def fetch_published_trigger(params:)
      trigger_class = Nodes::ComposerPaused::V1

      WorkflowDependency
        .cached_published_triggers(trigger_class.identifier)
        .find do |published_trigger|
          published_trigger.workflow_id == params.workflow_id &&
            published_trigger.trigger_node_id == params.trigger_node_id &&
            trigger_class.fires_on?(
              NodeData.parameters(published_trigger.trigger_node),
              trigger_class::PAUSE,
            )
        end
    end

    def fetch_topic(params:)
      ::Topic.find_by(id: params.topic_id) if params.composer_action == ComposerSnapshot::REPLY
    end

    def fetch_snapshot(params:, topic:, guardian:)
      ComposerSnapshot.new(
        user: guardian.user,
        action: params.composer_action,
        draft_key: params.draft_key,
        title: params.title,
        raw: params.raw,
        category_id: params.category_id,
        topic:,
        reply_to_post_number: params.reply_to_post_number,
      )
    end

    def can_fire_trigger(published_trigger:, snapshot:)
      Nodes::ComposerPaused::V1.matches_snapshot?(
        NodeData.parameters(published_trigger.trigger_node),
        snapshot,
      )
    end

    def fetch_matched_phrases(published_trigger:, snapshot:)
      Nodes::ComposerPaused::V1.matched_phrases(
        NodeData.parameters(published_trigger.trigger_node),
        snapshot.own_text,
      )
    end

    # The browser only asks after a match, but it is never trusted to have matched.
    def matches_phrases(published_trigger:, matched_phrases:)
      matched_phrases.present? ||
        Nodes::ComposerPaused::V1.phrases(
          NodeData.parameters(published_trigger.trigger_node),
        ).empty?
    end

    # Reopening the composer starts a new session, so its phrases can fire again.
    def fetch_new_phrases(params:, published_trigger:, matched_phrases:, guardian:)
      ComposerPausedClaims.claim(
        "session:#{guardian.user.id}:#{params.draft_key}:#{params.session_id}",
        published_trigger,
        matched_phrases,
      )
    end

    def has_new_phrases(new_phrases:)
      !new_phrases.nil?
    end

    def enqueue_workflow(published_trigger:, snapshot:, new_phrases:, guardian:)
      DiscourseWorkflows::TriggerDispatcher.enqueue(
        published_trigger,
        trigger_data: Nodes::ComposerPaused::V1.new(snapshot, new_phrases).output,
        user_id: guardian.user.id,
      )
    end
  end
end
