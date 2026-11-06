# frozen_string_literal: true

module DiscourseWorkflows
  # Fires composer paused triggers set to the draft autosave. Matching happens here, so their
  # phrases never reach the browser.
  class ComposerPausedDraftListener
    @queued_drafts = {}
    @queued_drafts_mutex = Mutex.new

    def self.handle(user, draft_key, data)
      return if !SiteSetting.enable_discourse_workflows
      return if draft_saved_triggers.empty?
      return if !ComposerPausedClaims.rate_limiter(user).can_perform?

      # Autosaves are frequent, so a draft waiting for its scan only takes the newest data.
      key = [RailsMultisite::ConnectionManagement.current_db, user.id, draft_key]
      return if !queue_draft(key, data)

      # Matching must not hold up the request. The queue is shared with unrelated work, so a
      # scan is dropped rather than added to a full queue.
      begin
        Scheduler::Defer.later(
          "discourse_workflows_composer_paused",
          current_user: user.id,
          force: false,
        ) do
          snapshot = ComposerSnapshot.from_draft(user, draft_key, take_queued_draft(key))
          new(snapshot).dispatch if snapshot
        end
      rescue StandardError
        # Nothing was queued, so the next autosave must queue a scan.
        take_queued_draft(key)
        raise
      end
    rescue WorkQueue::WorkQueueFull
      # Scans are best effort, so a busy queue skips this one.
    rescue => e
      Rails.logger.error("discourse-workflows: trigger:composer_paused failed: #{e.message}")
    end

    def self.draft_saved_triggers
      ComposerPausedDispatch.published_triggers(Nodes::ComposerPaused::V1::DRAFT_SAVED)
    end

    # Returns whether the draft needs a new scan, which it doesn't while one is queued.
    def self.queue_draft(key, data)
      @queued_drafts_mutex.synchronize do
        queued = @queued_drafts.key?(key)
        @queued_drafts[key] = data
        !queued
      end
    end

    def self.take_queued_draft(key)
      @queued_drafts_mutex.synchronize { @queued_drafts.delete(key) }
    end

    private_class_method :queue_draft, :take_queued_draft

    def initialize(snapshot)
      @snapshot = snapshot
    end

    def dispatch
      return if draft_id.nil?

      ComposerPausedDispatch.call(self.class.draft_saved_triggers, @snapshot, "draft:#{draft_id}")
    end

    private

    # A cleared draft is re-created with a new id, so the next post starts over.
    def draft_id
      return @draft_id if defined?(@draft_id)

      @draft_id =
        ::Draft.where(user_id: @snapshot.user.id, draft_key: @snapshot.draft_key).pick(:id)
    end
  end
end
