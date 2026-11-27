export default function migrate(settings) {
  if (settings.has("sidebar_groups")) {
    settings.set("sidebar_sections", settings.get("sidebar_groups"));
    settings.delete("sidebar_groups");
  }
  return settings;
}
