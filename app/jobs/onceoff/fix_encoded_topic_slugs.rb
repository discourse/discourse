# frozen_string_literal: true

module Jobs

  class FixEncodedTopicSlugs < ::Jobs::Onceoff
    def execute_onceoff(args)
      return unless SiteSetting.slug_generation_method == 'encoded'

      #Make all slugs nil and let the app regenerate with proper encoded ones
      Topic.update_all(slug: nil)
    end
  end

end
