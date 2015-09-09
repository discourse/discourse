const LivePostCounts = Discourse.Model.extend({});

LivePostCounts.reopenClass({
  find() {
    return Discourse.ajax("/about/live_post_counts.json").then(result => LivePostCounts.create(result));
  }
});

export default LivePostCounts;
