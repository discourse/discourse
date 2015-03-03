export default Discourse.Model.extend({
  post: null,
  options: [],
  closed: false,

  postObserver: function() {
    this.updateFromJson(this.get('post.poll_details'));
  }.observes('post.poll_details'),

  fetchNewPostDetails: Discourse.debounce(function() {
    this.get('post.topic.postStream').triggerChangedPost(this.get('post.id'), this.get('post.topic.updated_at'));
  }, 250).observes('post.topic.title'),

  updateFromJson(json) {
    const selectedOption = json["selected"];
    let options = [];

    Object.keys(json["options"]).forEach(function(option) {
      options.push(Ember.Object.create({
        option: option,
        votes: json["options"][option],
        checked: option === selectedOption
      }));
    });

    this.setProperties({ options: options, closed: json.closed });
  },

  saveVote(option) {
    this.get('options').forEach(function(opt) {
      opt.set('checked', opt.get('option') === option);
    });

    const self = this;
    return Discourse.ajax("/poll", {
      type: "PUT",
      data: { post_id: this.get('post.id'), option: option }
    }).then(function(newJSON) {
      self.updateFromJson(newJSON);
    });
  }
});
