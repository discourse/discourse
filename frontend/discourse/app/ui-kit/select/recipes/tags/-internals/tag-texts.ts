import type {
  SelectCoreTextKey,
  SelectTexts,
} from "discourse/ui-kit/select/select-engine";

/** The texts a tag picker accepts: the engine's and the tag recipe's. */
export type SelectTagTextKey =
  | SelectCoreTextKey
  | "addMoreTags"
  | "requiredTagGroup"
  | "requiredTagGroupRemaining"
  | "minimumPlaceholder"
  | "minimumRemaining"
  | "tagCountBadge"
  | "tagCount";

/**
 * The tag texts. The prompt stays the select's own, so a call site words it for its context; the
 * requirement steps come before it, and the panel's minimum line counts progress so it never
 * repeats the field's "Select at least…".
 */
export const TAG_TEXTS: SelectTexts = Object.freeze({
  addMorePlaceholder: (_values, context) => context.text("addMoreTags"),
  minimum: { translationKey: "tagging.required_tags_progress" },
  maximum: { translationKey: "tagging.max_tags_reached" },
  requiredTagGroup: {
    translationKey: "tagging.choose_for_topic_required_group",
  },
  requiredTagGroupRemaining: {
    translationKey: "tagging.choose_more_required_group",
  },
  minimumPlaceholder: { translationKey: "tagging.choose_for_topic_required" },
  minimumRemaining: { translationKey: "tagging.choose_more_required" },
  addMoreTags: { translationKey: "tagging.add_more_tags" },
  tagCountBadge: { translationKey: "tagging.tag_count_badge" },
  tagCount: { translationKey: "tagging.tag_count_hidden" },
});
