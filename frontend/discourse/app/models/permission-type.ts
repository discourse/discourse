import EmberObject, { computed } from "@ember/object";
import { i18n } from "discourse-i18n";

export function buildPermissionDescription(id: number): string {
  return i18n("permission_types." + PermissionType.DESCRIPTION_KEYS[id]);
}

/** Client-assigned permission data. Plugins may augment these fields. */
export interface PermissionTypeFields {
  id: number;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface PermissionType extends PermissionTypeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class PermissionType extends EmberObject {
  static FULL = 1;
  static CREATE_POST = 2;
  static READONLY = 3;
  static DESCRIPTION_KEYS: Record<number, string | undefined> = {
    1: "full",
    2: "create_post",
    3: "readonly",
  };

  @computed("id")
  get description(): string {
    return buildPermissionDescription(this.id);
  }
}
