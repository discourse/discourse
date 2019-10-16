# frozen_string_literal: true

module Jobs

  class FixEncodedCategorySlugs < ::Jobs::Onceoff
    def execute_onceoff(args)
      return unless SiteSetting.slug_generation_method == 'encoded'

      #Make custom categories slugs nil and let the app regenerate with proper encoded ones
      Category.all.reject { |c| c.seeded? }.each do |c|
        c.slug = nil
        c.save!
      end
    end
  end

end
