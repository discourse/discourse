import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { cook } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import RestModel from "discourse/models/rest";
import Category from "./category.ts";

/** Queued activity records from the pending-post serializer, not topic pending_posts. */
export interface PendingPostFields {
  id: number;
  created_at: string;
  category_id: number | null;
  topic_id: number | null;
  created_by_id: number | null;
  avatar_template: string | null;
  username: string | null;
  name: string | null;
  topic_url: string | null;
  raw_text: string | null;
  title: string | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface PendingPost extends PendingPostFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class PendingPost extends RestModel {
  expandedExcerpt: string | TrustedHTML | null = null;

  truncated = false;

  @tracked _postUrlOverride: string | null | undefined;

  init(...args: Parameters<RestModel["init"]>) {
    super.init(...args);
    cook(this.raw_text).then((cooked) => {
      this.set("expandedExcerpt", cooked);
    });
  }

  @computed("topic_url")
  get postUrl() {
    if (this._postUrlOverride !== undefined) {
      return this._postUrlOverride;
    }
    return this.topic_url;
  }

  set postUrl(value: string | null | undefined) {
    this._postUrlOverride = value;
  }

  @computed("username")
  get userUrl(): string {
    // The activity UI assumes a user is present, even though deleted users serialize null.
    return userPath(this.username!.toLowerCase());
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }
}
