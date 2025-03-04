# frozen_string_literal: true

module Jobs
  class CleanUpBookmarks < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      Bookmark.cleanup!
    end
  end
end
