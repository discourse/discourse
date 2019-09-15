# frozen_string_literal: true

module Jobs

  class DestroyOldHiddenPosts < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.delete_old_hidden_posts
      PostDestroyer.destroy_old_hidden_posts
    end

  end

end
