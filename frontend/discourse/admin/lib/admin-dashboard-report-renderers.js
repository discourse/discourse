import CoreReportCard from "discourse/admin/components/dashboard/report-cards/core-report";

const renderers = new Map();

export function registerAdminDashboardReportRenderer(source, ComponentClass) {
  renderers.set(source, ComponentClass);
}

export function lookupAdminDashboardReportRenderer(source) {
  if (source === "core_report") {
    return CoreReportCard;
  }
  return renderers.get(source);
}

export function resetAdminDashboardReportRenderers() {
  renderers.clear();
}
