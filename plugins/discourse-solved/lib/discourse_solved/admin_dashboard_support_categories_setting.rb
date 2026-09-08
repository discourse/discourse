# frozen_string_literal: true

module DiscourseSolved
  # Persistable setting for the "Support" admin dashboard section's category
  # filter, registered via `register_admin_dashboard_section`'s `settings:`.
  class AdminDashboardSupportCategoriesSetting
    MAX_CATEGORY_IDS = 10

    class << self
      def permit
        [{ category_ids: [] }]
      end

      def validate(attrs)
        ids = attrs[:category_ids]
        raise Discourse::InvalidParameters.new(:category_ids) if !ids.is_a?(Array)

        parsed = ids.map { |id| Integer(id, exception: false) }

        if parsed.size > MAX_CATEGORY_IDS || parsed.any?(&:nil?) || parsed.uniq.size != parsed.size
          raise Discourse::InvalidParameters.new(:category_ids)
        end

        if parsed.present? && Category.where(id: parsed).count != parsed.size
          raise Discourse::InvalidParameters.new(:category_ids)
        end

        { "category_ids" => parsed }
      end
    end
  end
end
