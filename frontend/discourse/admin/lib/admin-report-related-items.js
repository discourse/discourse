const renderers = new Map();

export function registerAdminReportRelatedItemsRenderer(reportType, renderer) {
  renderers.set(reportType, renderer);
}

export function adminReportRelatedItemsRenderer(reportType) {
  return renderers.get(reportType);
}

export function resetAdminReportRelatedItemsRenderers() {
  renderers.clear();
}
