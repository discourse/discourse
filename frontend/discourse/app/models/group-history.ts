import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import type { TopicBasicUser } from "discourse/models/topic";
import { i18n } from "discourse-i18n";

export interface GroupHistoryFields {
  action: string;
  subject: string | null;
  prev_value: string | null;
  new_value: string | null;
  created_at: string;
  acting_user: TopicBasicUser | null;
  target_user: TopicBasicUser | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface GroupHistory extends GroupHistoryFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class GroupHistory extends RestModel {
  @computed("action")
  get actionTitle(): string {
    return i18n(`group_histories.actions.${this.action}`);
  }
}
