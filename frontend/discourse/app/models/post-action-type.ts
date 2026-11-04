import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export const MAX_MESSAGE_LENGTH = 500;

/** Fields shared by site action types and admin flags, including the legacy serializer. */
export interface PostActionTypeFields {
  id: number;
  name: string;
  name_key: string;
  description: string;
  short_description: string;
  applies_to: string[];
  require_message: boolean;
  enabled: boolean;
  is_flag: boolean;
  is_used: boolean;
  system: boolean;
  /** Omitted by the legacy flag-settings serializer. */
  position?: number;
  /** Omitted by the legacy flag-settings serializer. */
  auto_action_type?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface PostActionType extends PostActionTypeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class PostActionType extends RestModel {
  @computed("name_key")
  get isIllegal() {
    return this.name_key === "illegal";
  }

  @computed()
  get translatedDescription(): string {
    if (this.system) {
      return i18n(`post.actions.by_you.${this.name_key}`);
    }
    return i18n(`post.actions.by_you.custom`, {
      custom: this.name,
    });
  }
}
