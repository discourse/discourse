# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinder
    MAX_USERNAME_LENGTH = 60

    def initialize(shared_data)
      @used_usernames_lower = shared_data.load(:usernames)
      @used_group_names_lower = shared_data.load(:group_names)
      @last_suffixes = {}

      @fallback_username =
        UserNameSuggester.sanitize_username(I18n.t("fallback_username")).presence ||
          UserNameSuggester::LAST_RESORT_USERNAME
      @fallback_group_name = "group"
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
        find_available_name(group_name, fallback_name: @fallback_group_name)

      @used_group_names_lower.add(group_name_lower)
      group_name
    end

    private

    def name_available?(name, allow_reserved_username: false)
      name_lower = name.downcase

      return false if @used_usernames_lower.include?(name_lower)
      return false if @used_group_names_lower.include?(name_lower)
      return false if !allow_reserved_username && User.reserved_username?(name_lower)
      true
    end

    def find_available_name(
      name,
      fallback_name:,
      max_name_length: nil,
      allow_reserved_username: false
    )
      name = name.unicode_normalize
      name = UserNameSuggester.sanitize_username(name)
      name = fallback_name.dup if name.blank?
      name = UserNameSuggester.truncate(name, max_name_length) if max_name_length

      if !name_available?(name, allow_reserved_username:)
        # if the name ends with a number, then use an underscore before appending the suffix
        suffix_separator = name.match?(/\d$/) ? "_" : ""
        suffix = next_suffix(name).to_s

        # TODO This needs better logic, because it's possible that the max username length is exceeded
        name = +"#{name}#{suffix_separator}#{suffix}"
        name.next! until name_available?(name, allow_reserved_username:)
      end

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
  end
end
