import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const LivePostCounts = EmberObject.extend({});

LivePostCounts.reopenClass({
  find() {
    return ajax("/about/live_post_counts.json").then(result =>
      LivePostCounts.create(result)
    );
  }
});

export default LivePostCounts;
