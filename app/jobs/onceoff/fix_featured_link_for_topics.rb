# frozen_string_literal: true

module Jobs
  class FixFeaturedLinkForTopics < ::Jobs::Onceoff
    def execute_onceoff(args)
      Topic
        .where("featured_link IS NOT NULL")
        .find_each do |topic|
          featured_link = topic.featured_link

          begin
            URI.parse(featured_link)
          rescue URI::Error
            topic.update(featured_link: URI.extract(featured_link).first)
          end
        end
    end
  end
end
