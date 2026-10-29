import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** Aggregate counts returned by the live counts endpoint. */
export interface LivePostCountsFields {
  public_topic_count: number;
  public_post_count: number;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface LivePostCounts extends LivePostCountsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class LivePostCounts extends EmberObject {
  static find(): Promise<LivePostCounts> {
    return ajax("/about/live_post_counts.json").then(
      (result: LivePostCountsFields) => LivePostCounts.create(result)
    );
  }
}
