import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class LivePostCounts extends EmberObject {
  static find() {
    return ajax("/about/live_post_counts.json").then((result) =>
      LivePostCounts.create(result)
    );
  }
}
