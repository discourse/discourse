# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinder
    MAX_USERNAME_LENGTH = 60
    MAX_GROUP_NAME_LENGTH = 60
    MAX_ATTEMPTS = 500

    private_constant :MAX_USERNAME_LENGTH, :MAX_GROUP_NAME_LENGTH, :MAX_ATTEMPTS

    def initialize(shared_data)
      @used_usernames_lower = shared_data.load(:usernames)
      @used_group_names_lower = shared_data.load(:group_names)
      @last_suffixes = {}

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
          max_name_length: MAX_USERNAME_LENGTH,
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
          max_name_length: MAX_GROUP_NAME_LENGTH,
        )

      @used_group_names_lower.add(group_name_lower)
      group_name
    end

    private

    def name_available?(name, allow_reserved_username: false)
      name_lower = name.downcase

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
      name = fallback_name.dup if name.blank?
      name = UserNameSuggester.truncate(name, max_name_length)

      return name, name.downcase if name_available?(name, allow_reserved_username:)

      original_base_name = name
      current_base_name = original_base_name
      current_base_clusters = current_base_name.grapheme_clusters
      current_base_length = current_base_clusters.size

      while !name_available?(name, allow_reserved_username:)
        # if the name ends with a number, then use an underscore before appending the suffix
        suffix_separator = name.match?(/\d$/) ? "_" : ""
        suffix = next_suffix(name).to_s

        required_length = current_base_length + suffix_separator.length + suffix.length

        if required_length > max_name_length
          # Truncate base further and reset suffix tracking
          chars_to_remove = required_length - max_name_length
          current_base_length -= chars_to_remove
          current_base_clusters = current_base_clusters[0...current_base_length]
          current_base_name = current_base_clusters.join
          # Reset suffix for the new base
          @last_suffixes[current_base_name.downcase] = 0
          suffix = next_suffix(current_base_name).to_s
          suffix_separator = current_base_name.match?(/\d$/) ? "_" : ""
        end
      end

      # if !name_available?(name, allow_reserved_username:)
      #   # if the name ends with a number, then use an underscore before appending the suffix
      #   suffix_separator = name.match?(/\d$/) ? "_" : ""
      #   suffix = next_suffix(name).to_s
      #
      #   # TODO This needs better logic, because it's possible that the max username length is exceeded
      #   name = +"#{name}#{suffix_separator}#{suffix}"
      #   name.next! until name_available?(name, allow_reserved_username:)
      # end

      [name, name.downcase]
    end

    def next_suffix(name)
      name_lower = name.downcase
      @last_suffixes.fetch(name_lower, 0) + 1
    end

    def store_last_suffix(name)
      name_lower = name.downcase
      @last_suffixes[$1] = $2.to_i if name_lower =~ /^(.+?)(\d+)$/
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
