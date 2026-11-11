import RestCompatModel from "discourse/data/rest-compat";
import { TagGroupSchema } from "discourse/data/schemas/tag-group";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import PermissionType from "discourse/models/permission-type";
import type { TagReference } from "discourse/models/tag";

/** TagGroupSerializer fields; new drafts initially contain only a name. */
export interface TagGroupFields {
  id: number;
  name: string;
  tags?: TagReference[];
  /** Empty, or the single parent tag. */
  parent_tag?: TagReference[];
  /** The column is nullable despite its default. */
  one_per_topic?: boolean | null;
  /** Permission types keyed by group id, with 0 representing everyone. */
  permissions?: Record<string, number>;
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TagGroup extends TagGroupFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TagGroup extends RestCompatModel {
  static override type = "tag-group";

  declare id: number;

  get permissionName(): "public" | "visible" | "private" {
    if (!this.permissions) {
      return "public";
    }

    if (this.permissions[0] === PermissionType.FULL) {
      return "public";
    } else if (this.permissions[0] === PermissionType.READONLY) {
      return "visible";
    } else {
      return "private";
    }
  }
}

defineFieldForwarders(TagGroup, TagGroupSchema);
