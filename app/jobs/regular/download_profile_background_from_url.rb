module Jobs

  class DownloadProfileBackgroundFromUrl < Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      url = args[:url]
      user_id = args[:user_id]

      raise Discourse::InvalidParameters.new(:url) if url.blank?
      raise Discourse::InvalidParameters.new(:user_id) if user_id.blank?

      return unless user = User.find_by(id: user_id)

      begin
        UserProfile.import_url_for_user(
          url,
          user,
          is_card_background: args[:is_card_background],
        )
      rescue Discourse::InvalidParameters => e
        raise e unless e.message == 'url'
      end
    end

  end

end
