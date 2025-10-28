# frozen_string_literal: true

module Migrations::Importer
  class GroupNameFinder < UniqueNameFinderBase
    private

    def load_from_shared_data(shared_data)
      @used_usernames_lower = shared_data&.load(:usernames) || Set.new
      @used_group_names_lower = shared_data&.load(:group_names) || Set.new

      build_reserved_username_cache
    end

    def store_used_name(name_lower)
      @used_group_names_lower.add(name_lower)
    end

    def existing_name_collections
      [@used_usernames_lower, @used_group_names_lower]
    end

    def fallback_name
      I18n.t("importer.fallback_names.group")
    end

    def sanitize_name(name)
      UserNameSuggester.sanitize_username(name)
    end

    def name_available?(name_lower)
      return false if @used_usernames_lower.include?(name_lower)
      return false if @used_group_names_lower.include?(name_lower)
      return false if @exact_reserved_usernames.include?(name_lower)
      true
    end

    def modify_truncated_name(name)
      name.gsub!(UsernameValidator::INVALID_TRAILING_CHAR_PATTERN, "")
      name
    end

    def build_reserved_username_cache
      @exact_reserved_usernames = Set.new

      if (here_mention = SiteSetting.here_mention.presence)
        @exact_reserved_usernames << here_mention.unicode_normalize.downcase
      end
    end
  end
end
