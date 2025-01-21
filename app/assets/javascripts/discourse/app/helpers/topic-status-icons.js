import deprecated from "discourse/lib/deprecated";
import { RAW_TOPIC_LIST_DEPRECATION_OPTIONS } from "discourse/lib/plugin-api";

const TopicStatusIcons = new (class {
  entries = [];

  addObject(entry) {
    deprecated(
      "TopicStatusIcons is deprecated. Use 'after-topic-status' plugin outlet instead.",
      RAW_TOPIC_LIST_DEPRECATION_OPTIONS
    );

    const [attribute, iconName, titleKey] = entry;
    this.entries.push({ attribute, iconName, titleKey });
  }
})();

export default TopicStatusIcons;
