// Registry for plugin-provided sections in the redesigned admin dashboard.
// Plugins register a component for a section id via
// `api.registerAdminDashboardSection`; the section id must match the one
// registered server-side with `register_admin_dashboard_section`.

const sections = new Map();

export function registerAdminDashboardSection(id, ComponentClass) {
  sections.set(id, ComponentClass);
}

export function lookupAdminDashboardSection(id) {
  return sections.get(id);
}

export function resetAdminDashboardSections() {
  sections.clear();
}
