# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinder
    MAX_LENGTH = ::UsernameValidator::MAX_CHARS
    MAX_ATTEMPTS = 500
    SUFFIX_CACHE_SIZE = 1000

    private_constant :MAX_LENGTH, :MAX_ATTEMPTS, :SUFFIX_CACHE_SIZE

    def initialize(shared_data)
      @used_usernames_lower = shared_data ? shared_data.load(:usernames) : Set.new
      @used_group_names_lower = shared_data ? shared_data.load(:group_names) : Set.new
      @last_suffixes = ::LruRedux::Cache.new(SUFFIX_CACHE_SIZE)

      @fallback_username =
        UserNameSuggester.sanitize_username(I18n.t("fallback_username")).presence ||
          UserNameSuggester::LAST_RESORT_USERNAME
      @fallback_group_name = "group"

      build_reserved_username_cache
    end

    def find_available_username(username, allow_reserved_username: false)
      username, username_lower =
        find_available_name(
          username,
          fallback_name: @fallback_username,
          max_name_length: MAX_LENGTH,
          allow_reserved_username:,
        )

      @used_usernames_lower.add(username_lower)
      username
    end

    def find_available_group_name(group_name)
      group_name, group_name_lower =
        find_available_name(
          group_name,
          fallback_name: @fallback_group_name,
          max_name_length: MAX_LENGTH,
        )

      @used_group_names_lower.add(group_name_lower)
      group_name
    end

    private

    def name_available?(name_lower, allow_reserved_username: false)
      return false if @used_usernames_lower.include?(name_lower)
      return false if @used_group_names_lower.include?(name_lower)
      return false if !allow_reserved_username && reserved_username?(name_lower)
      true
    end

    # Optimized version of User.reserved_username?
    def reserved_username?(name_lower)
      @exact_reserved_usernames.include?(name_lower) ||
        @wildcard_reserved_patterns.any? { |pattern| name_lower.match?(pattern) }
    end

    def matches_suffix_wildcard?(name_lower)
      @suffix_wildcard_patterns.any? { |pattern| name_lower.match?(pattern) }
    end

    def find_available_name(name, fallback_name:, max_name_length:, allow_reserved_username: false)
      name = UserNameSuggester.sanitize_username(name)

      if name.present?
        name = truncate_to(name, max_length: max_name_length)
        name_lower = name.downcase

        # Early return if name is available without suffix
        return name, name_lower if name_available?(name_lower, allow_reserved_username:)

        # Switch to fallback if suffixes won't help (matches _* wildcard)
        if !allow_reserved_username && matches_suffix_wildcard?(name_lower)
          name = fallback_name
          name_lower = name.downcase
        end
      else
        name = fallback_name
        name_lower = name.downcase
      end

      find_name_with_suffix(
        name,
        name_lower,
        fallback_name,
        max_name_length,
        allow_reserved_username,
      )
    end

    def find_name_with_suffix(
      name,
      name_lower,
      fallback_name,
      max_name_length,
      allow_reserved_username
    )
      original_suffix = suffix = next_suffix(name_lower)
      name_candidate_lower = +"#{name_lower}_#{suffix}"
      attempts = 0

      while attempts < MAX_ATTEMPTS
        if (overflow = name_candidate_lower.length - max_name_length) > 0
          store_last_suffix(name_lower, suffix) if original_suffix != suffix

          name = truncate_by(name, chars: overflow)
          name = fallback_name if name.length == 0
          name_lower = name.downcase

          suffix = next_suffix(name_lower)
          name_candidate_lower.replace("#{name_lower}_#{suffix}")
        elsif name_available?(name_candidate_lower, allow_reserved_username:)
          store_last_suffix(name_lower, suffix)
          return "#{name}_#{suffix}", name_candidate_lower
        else
          name_candidate_lower.next!
          suffix += 1
        end

        attempts += 1
      end

      nil
    end

    def next_suffix(name_lower)
      (@last_suffixes.fetch(name_lower) || 0) + 1
    end

    def store_last_suffix(name_lower, suffix)
      @last_suffixes[name_lower] = suffix
    end

    def truncate_to(name, max_length:)
      return name if name.length <= max_length

      result = +""
      name.each_grapheme_cluster do |cluster|
        break if result.length + cluster.length > max_length
        result << cluster
      end
      result
    end

    def truncate_by(name, chars:)
      truncate_to(name, max_length: name.length - chars)
    end

    def build_reserved_username_cache
      @exact_reserved_usernames = Set.new
      @wildcard_reserved_patterns = []
      @suffix_wildcard_patterns = []

      if SiteSetting.here_mention.present?
        @exact_reserved_usernames << SiteSetting.here_mention.unicode_normalize.downcase
      end

      SiteSetting.reserved_usernames_map.each do |reserved|
        normalized = reserved.unicode_normalize.downcase

        if normalized.include?("*")
          pattern = /\A#{Regexp.escape(normalized).gsub('\*', ".*")}\z/
          @wildcard_reserved_patterns << pattern
          @suffix_wildcard_patterns << pattern if normalized.end_with?("*")
        else
          @exact_reserved_usernames << normalized
        end
      end
    end
  end
end
