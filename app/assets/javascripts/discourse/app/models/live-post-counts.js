import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

const LivePostCounts = EmberObject.extend({});

LivePostCounts.reopenClass({
  find() {
    return ajax("/about/live_post_counts.json").then((result) =>
      LivePostCounts.create(result)
    );
  },
});

export default LivePostCounts;
