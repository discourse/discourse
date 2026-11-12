# frozen_string_literal: true

# Reacts to the `remove_and_replace_uncategorized` upcoming change being
# enabled or disabled (manually or via auto-promotion). See
# config/initializers/015-track-upcoming-change-toggle.rb for the dispatch.
#
# The site's prior state is snapshotted onto the change's UpcomingChangeEvent
# so that opt-out can restore the special category, and a category the site
# never exposed can be removed.

class SiteSetting::Action::RemoveAndReplaceUncategorizedToggled < Service::ActionBase
  UPCOMING_CHANGE = :remove_and_replace_uncategorized

  SNAPSHOT_EVENT_TYPES = %i[manual_opt_in automatically_promoted].freeze

  option :enabled

  def call
    enabled ? enable : disable
  end

  def self.should_display_upcoming_change?
    SiteSetting.allow_uncategorized_topics || UpcomingChanges.enabled?(UPCOMING_CHANGE)
  end

  private

  def enable
    demote if SiteSetting.uncategorized_category_id != -1
    remove_unused_category
  end

  def demote
    event = snapshot_events.last
    return if event.nil?

    allow_uncategorized_topics = SiteSetting.allow_uncategorized_topics
    default_composer_category = SiteSetting.default_composer_category
    uncategorized_category_id = SiteSetting.uncategorized_category_id

    ActiveRecord::Base.transaction do
      if stored_snapshot.blank?
        event.update!(
          event_data: {
            allow_uncategorized_topics:,
            default_composer_category:,
            uncategorized_category_id:,
          },
        )
      end

      if allow_uncategorized_topics && default_composer_category.blank?
        SiteSetting.set_and_log(:default_composer_category, uncategorized_category_id.to_s)
      end

      # Definition topics were skipped for the special category only by virtue
      # of `uncategorized_category_id` pointing at it, so move the exemption
      # onto the category before it stops matching.
      Category.find_by(id: uncategorized_category_id)&.upsert_custom_fields(
        Category::SKIP_DEFINITION_CUSTOM_FIELD => true,
      )

      SiteSetting.set_and_log(:uncategorized_category_id, -1)
      SiteSetting.set_and_log(:allow_uncategorized_topics, false)
    end

    Site.clear_cache
  end

  def remove_unused_category
    snapshot = stored_snapshot
    return if snapshot.blank? || snapshot["allow_uncategorized_topics"]

    category = Category.find_by(id: snapshot["uncategorized_category_id"])
    guardian = Discourse.system_user.guardian
    return if category.nil? || !guardian.can_delete_category?(category) || !pristine?(category)

    CategoryDestroyer.destroy(guardian, category)
  end

  def pristine?(category)
    category.name == I18n.t("uncategorized_category_name", locale: SiteSetting.default_locale) &&
      category.category_groups.none? && !category.topics.with_deleted.exists?
  end

  def disable
    snapshot = stored_snapshot
    return if snapshot.blank? || !snapshot["allow_uncategorized_topics"]

    category = Category.find_by(id: snapshot["uncategorized_category_id"])
    return if category.nil?

    ActiveRecord::Base.transaction do
      SiteSetting.set_and_log(:uncategorized_category_id, category.id)
      SiteSetting.set_and_log(:allow_uncategorized_topics, true)
      SiteSetting.set_and_log(
        :default_composer_category,
        snapshot["default_composer_category"].to_s,
      )

      # The category is special again, so the setting covers it once more and
      # the exemption returns to being absent rather than explicitly false.
      category.custom_fields.delete(Category::SKIP_DEFINITION_CUSTOM_FIELD)
      category.save_custom_fields
    end

    Site.clear_cache
  end

  def stored_snapshot
    snapshot_events.where.not(event_data: nil).last&.event_data
  end

  def snapshot_events
    UpcomingChangeEvent.where(
      upcoming_change_name: UPCOMING_CHANGE,
      event_type: SNAPSHOT_EVENT_TYPES,
    )
  end
end
