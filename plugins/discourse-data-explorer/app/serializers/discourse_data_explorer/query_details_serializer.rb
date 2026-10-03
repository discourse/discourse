# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryDetailsSerializer < QuerySerializer
    attributes :sql, :param_info, :created_at, :hidden, :dashboard_mountable, :dashboard_mounted

    def include_sql?
      scope&.is_admin?
    end

    def param_info
      object&.params&.uniq { |p| p.identifier }&.map(&:to_hash)
    end

    def dashboard_mountable
      AdminDashboardReportProvider.mountable?(object)
    end

    def include_dashboard_mountable?
      scope&.is_admin?
    end

    def dashboard_mounted
      AdminDashboardReportProvider.mounted?(object)
    end

    def include_dashboard_mounted?
      scope&.is_admin?
    end
  end
end
