export function prioritizeNameInUx(name, siteSettings) {
  siteSettings = siteSettings || Discourse.SiteSettings;

  return (
    !siteSettings.prioritize_username_in_ux && name && name.trim().length > 0
  );
}
