# frozen_string_literal: true

require "distributed_cache"

class ApplicationSerializer < ActiveModel::Serializer
  embed :ids, include: true

  # NB: Set environment variable STRICT_SERIALIZER_SCOPE to either
  #     "nil_or_guardian" or "only_guardian" to enforce stricter checking
  #     of scope parameters.
  #
  #     See notes in initialize(), below, and in PlaceholderGuardian.new
  #
  @@require_strict_scope = ENV["STRICT_SERIALIZER_SCOPE"]&.intern

  def self.require_strict_scope
    @@require_strict_scope
  end

  def initialize(*args)
    # Ensure that a scope: argument was provided to this Serializer.
    #
    # In a test environment, we treat this as an assertion and fail hard if no
    # "scope:" has been provided.  Outside of testing, we merely log an error,
    # since there are codepaths (that have no test coverage, apparently) that
    # manage to function without a scope, and we do not want to break them in
    # production.
    #
    # If you are reading this because you have encountered this warning/error,
    # then you should add an appropriate "scope:" argument to the call-site
    # which triggered it.
    #
    #  * If one serializer is constructing another one, simply forwarding the
    #    scope of the parent serializer is almost always the right thing to do,
    #    e.g., add "scope: scope".
    #
    #  * The scope should be a Guardian instance.  If there is already a
    #    Guardian instance available (e.g., within the context of a Controller),
    #    then simply using it is almost always the right thing to do,
    #    e.g., add "scope: guardian".
    #
    #  * The guiding principle is that the Guardian should reflect what the
    #    potential receiver of the serialized object is allowed to receive.
    #    E.g., if the serialized object is going to be sent to user_x, then
    #    a Guardian reflecting user_x ("Guardian.new(user_x)") is usually
    #    (but not always) correct.
    #
    #  * If it is not clear whose Guardian to use and you need to kick-the-can
    #    down-the-road a bit longer, use "scope: PlaceholderGuardian.new".  This
    #    will make it easy to track this technical debt and find it later on.
    #
    unless args[-1].has_key?(:scope)
      Rails.logger.error("Serializer initialized without scope:")
      raise "Serializer initialized without scope:" if ENV["RAILS_ENV"] == "test"
    end

    super

    # TODO (a) Impose the more stringent condition that every scope is either
    #          nil or an instance of Guardian.
    #          (I.e., set default @@require_strict_scope to :nil_or_guardian)
    #
    # TODO (b) Impose the even more stringent condition that every scope is
    #          only an instance of Guardian.
    #          (I.e., set default @@require_strict_scope to :only_guardian)
    #
    # Note, however:
    #
    #  1) There are bits of legacy code that provide non-Guardian scopes to
    #     certain serializers, so both (a) and (b) must wait until those bits
    #     are fixed (or, until someone is trying to find/fix those bits).
    #
    #  2) If there are still instances of "PlaceholderGuardian.new" in the
    #     code, then PlaceholderGuardian#new will need to be tweaked to
    #     generate "exploding placeholders" instead of nil, before (b) can
    #     be put into effect.  (See the explanation in PlaceholderGuardian.)
    #
    #  3) There are bits of legacy code that check for and paper-over nil
    #     scopes (e.g. "scope && scope.can_xxx?"), and these bits will explode
    #     if they encounter an "exploding placeholder".  So, these checks need
    #     to be removed before (2) can be done.
    #
    if @@require_strict_scope === :nil_or_guardian
      # Ensure that the scope is nil or an instance of Guardian.
      unless (nil === scope) || (Guardian === scope)
        Rails.logger.error("Serializer initialized with a non-nil-or-Guardian scope")
        if ENV["RAILS_ENV"] == "test"
          raise "Serializer initialized with a non-nil-or-Guardian scope"
        end
      end
    elsif @@require_strict_scope === :only_guardian
      # Ensure that the scope is precisely an instance of Guardian.
      unless Guardian === scope
        Rails.logger.error("Serializer initialized with a non-Guardian scope")
        if ENV["RAILS_ENV"] == "test"
          raise "Serializer initialized with a non-Guardian scope"
        end
      end
    end
  end

  class CachedFragment
    def initialize(json)
      @json = json
    end

    def as_json(*_args)
      @json
    end
  end

  def self.expire_cache_fragment!(name_or_regexp)
    case name_or_regexp
    when String
      fragment_cache.delete(name_or_regexp)
    when Regexp
      fragment_cache.clear_regex(name_or_regexp)
    end
  end

  def self.fragment_cache
    @cache ||= DistributedCache.new("am_serializer_fragment_cache")
  end

  protected

  def cache_fragment(name, &block)
    ApplicationSerializer.fragment_cache.defer_get_set(name, &block)
  end

  def cache_anon_fragment(name, &blk)
    if scope.anonymous?
      cache_fragment(name, &blk)
    else
      blk.call
    end
  end
end
