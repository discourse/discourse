# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinder
    MAX_LENGTH = ::UsernameValidator::MAX_CHARS
    MAX_ATTEMPTS = 500
    SUFFIX_CACHE_SIZE = 1000

    private_constant :MAX_LENGTH, :MAX_ATTEMPTS, :SUFFIX_CACHE_SIZE

    def initialize(shared_data)
      @used_usernames_lower = shared_data.load(:usernames)
      @used_group_names_lower = shared_data.load(:group_names)
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
    def reserved_username?(username)
      @exact_reserved_usernames.include?(username) ||
        @wildcard_reserved_patterns.any? { |pattern| username.match?(pattern) }
    end

    def find_available_name(name, fallback_name:, max_name_length:, allow_reserved_username: false)
      name = UserNameSuggester.sanitize_username(name)

      if name.present?
        name = truncate(name, max_length: max_name_length)
        name_lower = name.downcase
        return name, name_lower if name_available?(name_lower, allow_reserved_username:)
      else
        name = fallback_name
        name_lower = name.downcase
      end

      suffix = next_suffix(name_lower)
      name_candidate_lower = +"#{name_lower}_#{suffix}"
      attempts = 0

      while attempts < MAX_ATTEMPTS
        if (overflow = name_candidate_lower.length - max_name_length) > 0
          store_last_suffix(name_lower, suffix)

          name = truncate(name, max_length: max_name_length - overflow)
          name = fallback_name if name.length == 0
          name_lower = name.downcase

          suffix = next_suffix(name_lower)
          name_candidate_lower.replace("#{name_lower}_#{suffix}")
        elsif name_available?(name_candidate_lower, allow_reserved_username:)
          store_last_suffix(name_lower, suffix)
          return "#{name}_#{suffix}", name_candidate_lower
        else
          name_candidate_lower.next!
        end

        attempts += 1
      end

      nil
    end

    def next_suffix(name_lower)
      ((@last_suffixes.fetch(name_lower) || 0) + 1).to_s
    end

    def store_last_suffix(name_lower, suffix)
      @last_suffixes[name_lower] = suffix.to_i
    end

    def truncate(name, max_length:)
      return name if name.length <= max_length

      result = +""
      name.each_grapheme_cluster do |cluster|
        break if result.length + cluster.length > max_length
        result << cluster
      end
      result
    end

    def build_reserved_username_cache
      @exact_reserved_usernames = Set.new
      @wildcard_reserved_patterns = []

      if SiteSetting.here_mention.present?
        @exact_reserved_usernames.add(SiteSetting.here_mention.unicode_normalize)
      end

      SiteSetting.reserved_usernames_map.each do |reserved|
        normalized = reserved.unicode_normalize
        if normalized.include?("*")
          pattern = /\A#{Regexp.escape(normalized).gsub('\*', ".*")}\z/
          @wildcard_reserved_patterns << pattern
        else
          @exact_reserved_usernames.add(normalized)
        end
      end
    end
  end
end
