# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinder
    def initialize(shared_data)
      @used_usernames_lower = shared_data.load(:usernames)
      @used_group_names_lower = shared_data.load(:group_names)
      @last_suffixes = {}
      @allowed_name_length_range = User.username_length
    end

    def find_available_username(username, allow_reserved_username: false)
      username, username_lower = find_available_name(username, allow_reserved_username:)
      @used_usernames_lower.add(username_lower)
      username
    end

    def find_available_group_name(group_name)
      group_name, group_name_lower = find_available_name(group_name, allow_reserved_username: false)
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

    # def valid_length?(name)
    #   @allowed_name_length_range.include?(name.grapheme_clusters.size)
    # end
    #
    # def find_for_long_name(name, allow_reserved_username: false)
    #   possible_name = name
    #
    #   while name_length > (max_name_length = @allowed_name_length_range.end - suffix.length - 1)
    #   end
    #
    #   name_length = possible_name.grapheme_clusters.size
    #   suffix = next_suffix(possible_name).to_s
    #
    #   max_name_length = @allowed_name_length_range.end - suffix.length - 1
    #   possible_name = UserNameSuggester.truncate(name, max_length)
    #
    #   while name_length > (max_name_length = @allowed_name_length_range.end - suffix.length - 1)
    #     suffix.next!
    #   end
    # end

    def find_available_name(name, allow_reserved_username: false)
      possible_name = name.unicode_normalize
      possible_name = UserNameSuggester.sanitize_username(possible_name)

      name_length = possible_name.grapheme_clusters.size

      if name_length > @allowed_name_length_range.end
        possible_name = UserNameSuggester.truncate(possible_name, @allowed_name_length_range.end)
        name_length = @allowed_name_length_range.end
      end

      if name_length < @allowed_name_length_range.end
        possible_name = find_name(possible_name, allow_reserved_username:)
      elsif !name_available?(possible_name, allow_reserved_username:)
        possible_name = truncate_and_find_name(possible_name, allow_reserved_username:)
      end

      raise "Couldn't find available name for '#{name}'" if possible_name.nil?

      [possible_name, possible_name.downcase]
    end

    def find_name(name, allow_reserved_username:)
      name_length = name.grapheme_clusters.size

      # if the name ends with a number, then use an underscore before appending the suffix
      suffix_separator = name.match?(/\d$/) ? "_" : ""
      suffix = next_suffix(name).to_s

      if (min_suffix_length = @allowed_name_length_range.begin - name_length) > 0
        suffix = suffix.rjust(min_suffix_length - suffix_separator.length, "0")
      end

      # `#length` is faster than checking `#grapheme_clusters`, so we are calculating
      # the max length in characters
      max_length = @allowed_name_length_range.end - name_length + name.length
      possible_name = +"#{name}#{suffix_separator}#{suffix}"

      while possible_name.length <= max_length
        possible_name.next!

        if name_available?(possible_name, allow_reserved_username:)
          store_last_suffix(possible_name)
          return possible_name
        end
      end

      nil
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
