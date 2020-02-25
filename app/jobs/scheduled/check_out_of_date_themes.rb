# frozen_string_literal: true

module Jobs
  class CheckOutOfDateThemes < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      target_themes = RemoteTheme
        .joins("JOIN themes ON themes.remote_theme_id = remote_themes.id")
        .where.not(remote_url: "")

      target_themes.each do |remote|
        remote.update_remote_version
        remote.save!
      end
    end
  end
end
