# frozen_string_literal: true

module Reports
  class Access
    def initialize(guardian:, purpose: :view)
      raise ArgumentError, "guardian is required" if guardian.nil?
      raise ArgumentError, "invalid report purpose" if %i[view export].exclude?(purpose)

      @guardian = guardian
      @purpose = purpose
    end

    def find(type:, options: {}, cache: false)
      type = type.to_s
      return unless allowed?(type)

      options = options.merge(guardian: @guardian, current_user: @guardian.user)
      if cache
        cached = Report.find_cached(type, options)
        return cached if cached
      end

      report = Report.find(type, options)
      Report.cache(report) if cache && report
      report
    end

    private

    def allowed?(type)
      if @purpose == :export
        @guardian.can_export_entity?("report", nil, name: type)
      else
        @guardian.is_staff? && !Report.hidden?(type, guardian: @guardian)
      end
    end
  end
end
