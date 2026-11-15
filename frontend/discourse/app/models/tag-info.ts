import RestCompatModel from "discourse/data/rest-compat";
import { TagInfoSchema } from "discourse/data/schemas/tag-info";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import type Category from "discourse/models/category";
import type {
  default as Tag,
  TagCountRow,
  TagLocalization,
} from "discourse/models/tag";

/** DetailedTagSerializer fields after category sideload hydration. */
export interface TagInfoFields {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  description_cooked: string | null;
  topic_count: number;
  staff: boolean;
  /** Sent only with content localization, when the tag's localizations are preloaded. */
  localizations?: TagLocalization[];
  /** Initially count rows; the controller replaces them with Tag instances. */
  synonyms: (TagCountRow | Tag)[];
  /** Sent to admins, or when tags are listed by group. */
  tag_group_names?: string[];
  category_restricted: boolean;
  /** Hydrated from the category sideload. */
  categories: Category[];
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TagInfo extends TagInfoFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TagInfo extends RestCompatModel {
  static override type = "tag-info";

  declare id: number;

  /** Retained when category sideload hydration has no records to attach. */
  declare category_ids?: number[];
}

defineFieldForwarders(TagInfo, TagInfoSchema);
