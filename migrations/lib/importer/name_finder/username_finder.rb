# frozen_string_literal: true

module Migrations::Importer
  class UsernameFinder < UniqueNameFinderBase
    def find_available_name(name, allow_reserved_username: false)
      @allow_reserved_username = allow_reserved_username
      super(name)
    end

    private

    def load_from_shared_data(shared_data)
      @used_usernames_lower = shared_data&.load(:usernames) || Set.new
      @used_group_names_lower = shared_data&.load(:group_names) || Set.new
      build_reserved_username_cache
    end

    def store_used_name(name_lower)
      @used_usernames_lower.add(name_lower)
    end

    def existing_name_collections
      [@used_usernames_lower, @used_group_names_lower]
    end

    def fallback_name
      I18n.t("importer.fallback_names.user")
    end

    def sanitize_name(name)
      UserNameSuggester.sanitize_username(name)
    end

    def name_available?(name_lower)
      return false if @used_usernames_lower.include?(name_lower)
      return false if @used_group_names_lower.include?(name_lower)
      return false if reserved_username?(name_lower)
      true
    end

    def should_skip_suffix_attempts?(name_lower)
      return false if @allow_reserved_username

      @suffix_wildcard_patterns.any? { |pattern| name_lower.match?(pattern) }
    end

    def reserved_username?(name_lower)
      return false if @allow_reserved_username

      @exact_reserved_usernames.include?(name_lower) ||
        @wildcard_reserved_patterns.any? { |pattern| name_lower.match?(pattern) }
    end

    def modify_truncated_name(name)
      name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, "")
      name
    end

    def build_reserved_username_cache
      @exact_reserved_usernames = Set.new
      @wildcard_reserved_patterns = []
      @suffix_wildcard_patterns = []

      if (here_mention = SiteSetting.here_mention.presence)
        @exact_reserved_usernames << here_mention.unicode_normalize.downcase
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
