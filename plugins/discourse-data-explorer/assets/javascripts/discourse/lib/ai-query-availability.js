export function dataExplorerAiQueriesEnabled(siteSettings) {
  return !!(
    siteSettings.data_explorer_ai_queries_enabled &&
    siteSettings.discourse_ai_enabled
  );
}
