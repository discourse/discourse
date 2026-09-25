const renderers = new Map();

export function registerAdminDashboardReportRenderer(source, ComponentClass) {
  renderers.set(source, ComponentClass);
}

export function lookupAdminDashboardReportRenderer(source) {
  return renderers.get(source);
}

export function resetAdminDashboardReportRenderers() {
  renderers.clear();
}
