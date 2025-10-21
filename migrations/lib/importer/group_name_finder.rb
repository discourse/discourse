# frozen_string_literal: true

module Migrations::Importer
  class GroupNameFinder < UniqueNameFinderBase
    def initialize(shared_data)
      @used_usernames_lower = shared_data&.load(:usernames) || Set.new
      super(shared_data)
    end

    protected

    def load_used_names(shared_data)
      shared_data&.load(:group_names) || Set.new
    end

    def max_length
      ::Group::MAX_NAME_LENGTH
    end

    def fallback_name
      "group"
    end

    def sanitize_name(name)
      UserNameSuggester.sanitize_username(name)
    end

    def additional_used_names_for_suffix_finder
      [@used_usernames_lower]
    end

    private

    def name_available?(name_lower, allow_reserved: false)
      return false if @used_usernames_lower.include?(name_lower)
      super
    end
  end
end
