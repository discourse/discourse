module Jobs

  class FeatureTopics < Jobs::Base

    def execute(args)
      CategoryFeaturedTopic.feature_topics
    end

  end

end
