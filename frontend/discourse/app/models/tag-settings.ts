import RestCompatModel from "discourse/data/rest-compat";
import { TagSettingsSchema } from "discourse/data/schemas/tag-settings";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import type Category from "discourse/models/category";
import type { TagLocalization } from "discourse/models/tag";

/** TagSettingsSerializer fields after category sideload hydration. */
export interface TagSettingsFields {
  id: number;
  name: string;
  locale: string | null;
  slug: string;
  description: string | null;
  description_cooked: string | null;
  synonyms: { id: number; name: string }[];
  /** Sent to admins, or when tags are listed by group. */
  tag_group_names?: string[];
  /** Sent to admins, or when tags are listed by group. */
  tag_groups?: { id: number; name: string }[];
  category_restricted: boolean;
  can_edit: boolean;
  can_admin: boolean;
  /** Hydrated from the category sideload. */
  categories: Category[];
  /** Sent only with content localization. */
  localizations?: TagLocalization[];
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TagSettings extends TagSettingsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TagSettings extends RestCompatModel {
  static override type = "tag-settings";

  declare id: number;

  /** Retained on empty hydration or applied directly from a save response. */
  declare category_ids?: number[];
}

defineFieldForwarders(TagSettings, TagSettingsSchema);
