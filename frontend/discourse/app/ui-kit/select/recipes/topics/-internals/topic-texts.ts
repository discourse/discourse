import type {
  SelectCoreTextKey,
  SelectTexts,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The texts a topic picker accepts: the engine's and the name of a held topic nothing found. */
export type SelectTopicTextKey = SelectCoreTextKey | "unresolved";

/** The topics a picker offers, as the archetype its search is restricted to. */
export type TopicPickerArchetype = "regular" | "private_message";

/** Names a held topic the viewer cannot see or that no longer exists, by its `id`. */
export const TOPIC_TEXTS: SelectTexts = Object.freeze({
  unresolved: { translationKey: "select_topic.unresolved" },
});

/** The picker's name, for topics or messages, one or several. */
export function topicPickerName({
  plural,
  archetype,
}: {
  /** Whether the field holds more than one. */
  plural: boolean;
  /** The archetype searched; messages have names of their own. */
  archetype?: TopicPickerArchetype | null;
}): string {
  if (archetype === "private_message") {
    return plural
      ? i18n("select_topic.messages")
      : i18n("select_topic.message");
  }
  return plural ? i18n("select_topic.topics") : i18n("select_topic.topic");
}

/** What the search field invites, for topics or messages. */
export function topicSearchPlaceholder(
  archetype?: TopicPickerArchetype | null
): string {
  return archetype === "private_message"
    ? i18n("select_topic.message_search_placeholder")
    : i18n("select_topic.search_placeholder");
}
