require_dependency 'email/sender'
require_dependency 'topic_retriever'

module Jobs
  # Asynchronously retrieve a topic from an embedded site
  class RetrieveTopic < Jobs::Base
    def execute(args)
      unless args[:embed_url].present?
        raise Discourse::InvalidParameters.new(:embed_url)
      end

      user = nil
      user = User.find_by(id: args[:user_id]) if args[:user_id]
      TopicRetriever.new(
        args[:embed_url],
        author_username: args[:author_username], no_throttle: user.try(:staff?)
      )
        .retrieve
    end
  end
end
