# frozen_string_literal: true

module ::Jobs
  class RecoverBlogSchedules < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = nil)
      return unless SiteSetting.blog_enabled

      Blog::Publication
        .where("scheduled_at <= ?", Time.current)
        .order(:scheduled_at)
        .limit(100)
        .pluck(:id, :schedule_token)
        .each do |publication_id, token|
          Jobs.enqueue(:publish_blog_revision, publication_id: publication_id, token: token)
        end
    end
  end
end
