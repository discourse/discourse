# typed: true

# ActiveSupport core extensions and the controller surface used by the typed
# admin dashboard code. Untyped on purpose — these are boundaries, not the
# subject of the spike.

class Object
  sig { returns(T::Boolean) }
  def blank?; end

  sig { returns(T::Boolean) }
  def present?; end

  sig { returns(T.nilable(T.self_type)) }
  def presence; end

  def as_json(options = nil); end
end

module Enumerable
  def index_by(&blk); end

  sig { params(object: T.untyped).returns(T::Boolean) }
  def exclude?(object); end
end

class Hash
  def symbolize_keys; end
end

class Time
  def self.zone; end
  def self.current; end
end

class Numeric
  def minute; end
  def minutes; end
end

module Admin
end

class Admin::StaffController
  def self.before_action(*args, **kwargs, &blk); end

  def params; end
  def render(*args); end
  def head(status); end
  def guardian; end
  def current_user; end
  def hijack(*args, &blk); end
  def render_json_dump(*args); end
  def serialize_data(*args, **kwargs); end
  def service_params; end
  def success_json; end
  def failed_json; end

  # Service DSL methods (UpcomingChanges::Toggle.call block) are instance
  # -exec'd; Sorbet sees them as self calls, so they are declared here.
  def on_success(&blk); end
  def on_failure(&blk); end
  def on_failed_policy(name, &blk); end
  def on_failed_contract(&blk); end
end

class AdminDashboardIndexData
  def self.fetch_cached_stats; end
end

class AdminDashboardGeneralData
  def self.fetch_cached_stats; end
end

class AdminDashboardSectionConfiguration
  def self.update(sections, actor:); end
  def self.visible_section_ids; end
  def self.sections; end
end

class AdminDashboardSectionLoader
  def self.build(section_ids:, current_user:, start_date:, end_date:); end
end

class SiteSetting
  def self.version_checks?; end
end

module DiscourseUpdates
  def self.check_version; end
  def self.new_features(force_refresh: false); end
  def self.merge_new_features_with_upcoming_changes(features); end
  def self.bump_last_viewed_feature_date(user_id, date); end
  def self.has_unseen_features?(user_id); end
  def self.mark_new_features_as_seen(user_id); end
end

class ProblemCheck
  def self.realtime; end
end

class RateLimiter
  def initialize(user, key, max, secs, **opts); end
  def performed!; end
end

module UpcomingChanges
  def self.enabled_for_user?(change, user); end

  class Toggle
    def self.call(params, &blk); end
  end
end

class AdminNotice
  def self.problem; end
end

class AdminNoticeSerializer
end
