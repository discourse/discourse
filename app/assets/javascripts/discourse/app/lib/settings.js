import deprecated from "discourse-common/lib/deprecated";

export function prioritizeNameInUx(name, siteSettings) {
  if (!siteSettings) {
    deprecated(
      "You must supply `prioritizeNameInUx` with a `siteSettings` object",
      {
        since: "2.6.0",
        dropFrom: "2.7.0"
      }
    );
    siteSettings = Discourse.SiteSettings;
  }

  return (
    !siteSettings.prioritize_username_in_ux && name && name.trim().length > 0
  );
}
