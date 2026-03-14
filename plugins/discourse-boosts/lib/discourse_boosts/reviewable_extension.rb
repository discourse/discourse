# frozen_string_literal: true

module DiscourseBoosts
  module ReviewableExtension
    extend ActiveSupport::Concern

    class_methods do
      def sti_class_mapping
        super.merge("ReviewableBoost" => DiscourseBoosts::ReviewableBoost)
      end

      def polymorphic_class_mapping
        super.merge("Boost" => DiscourseBoosts::Boost)
      end
    end
  end
end
