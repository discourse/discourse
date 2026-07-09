# typed: true

# Hand-written shims for the slice of Discourse/Rails that the typed
# lib/admin_dashboard code touches. A full adoption would generate these with
# Tapioca; for the spike we declare only what we call, mostly untyped, so the
# type boundary sits inside lib/admin_dashboard itself.

class Guardian
  def initialize(user = nil, request = nil); end
  def user; end
end

module Discourse
  class InvalidParameters < StandardError
    def initialize(name = nil); end
  end

  class InvalidAccess < StandardError
  end

  class NotFound < StandardError
  end

  def self.system_user; end
end

class Report
  def self.find_cached(type, opts = nil); end
  def self.find(type, opts = nil); end
  def self.cache(report); end

  sig { returns(T::Array[String]) }
  def self.dashboard_excluded_report_types; end
end

module Reports
  class ListQuery
    def self.call(guardian:); end
  end
end

class DiscoursePluginRegistry
  sig { returns(T::Array[T.untyped]) }
  def self.admin_dashboard_report_sources; end
end

class AdminDashboardReport
  VISIBLE_CAP = T.let(T.unsafe(nil), Integer)

  def self.order(*args, **kwargs); end
  def self.delete_all; end
  def self.insert_all(rows); end
  def self.transaction(&blk); end

  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def source; end

  sig { returns(String) }
  def identifier; end

  sig { returns(Integer) }
  def position; end

  def [](key); end
end
