export default function migrate(settings) {
  if (settings.get("topic_card_context") === "high_context") {
    settings.set("topic_card_high_context", true);
  }
  settings.delete("topic_card_context");
  return settings;
}
