import EmberObject from "@ember/object";
import type UserAction from "discourse/models/user-action";

export interface UserActionGroupFields {
  icon: string;
  items?: UserAction[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserActionGroup extends UserActionGroupFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserActionGroup extends EmberObject {
  push(item: UserAction): number {
    if (!this.items) {
      this.items = [];
    }
    return this.items.push(item);
  }
}
