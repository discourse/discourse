# frozen_string_literal: true

module Jobs
  class CleanUpTags < ::Jobs::Scheduled
    every 24.hours

    def execute(args)
      return unless SiteSetting.automatically_clean_tags
      Tag.unused.destroy_all
    end
  end
end
