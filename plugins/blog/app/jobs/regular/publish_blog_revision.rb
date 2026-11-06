# frozen_string_literal: true

module ::Jobs
  class PublishBlogRevision < ::Jobs::Base
    def execute(args)
      return unless UpcomingChanges.enabled?(:blog_enabled)

      Blog::Publication::RunSchedule.call(
        params: {
          publication_id: args[:publication_id],
          token: args[:token],
        },
      )
    end
  end
end
