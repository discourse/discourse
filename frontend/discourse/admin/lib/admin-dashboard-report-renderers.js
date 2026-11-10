import CoreReportCard from "discourse/admin/components/dashboard/report-cards/core-report";
import { applyValueTransformer } from "discourse/lib/transformer";

export function lookupAdminDashboardReportRenderer(source) {
  if (source === "core_report") {
    return CoreReportCard;
  }
  return applyValueTransformer("admin-dashboard-report-renderer", undefined, {
    source,
  });
}
