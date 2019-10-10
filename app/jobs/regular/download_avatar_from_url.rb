# frozen_string_literal: true

module Jobs

  class DownloadAvatarFromUrl < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      url = args[:url]
      user_id = args[:user_id]

      raise Discourse::InvalidParameters.new(:url) if url.blank?
      raise Discourse::InvalidParameters.new(:user_id) if user_id.blank?

      return unless user = User.find_by(id: user_id)

      begin
        UserAvatar.import_url_for_user(
          url,
          user,
          override_gravatar: args[:override_gravatar]
        )
      rescue Discourse::InvalidParameters => e
        raise e unless e.message == 'url'
      end
    end

  end

end
