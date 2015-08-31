export default Ember.Object.extend({
  renderDiv: function(){
    return this.get('statuses').length > 0 && !this.noDiv;
  }.property(),
  statuses: function(){
    var topic = this.get("topic");
    var results =  [];
    var self = this;

    // TODO, custom statuses? via override?

    if(topic.get('is_warning')){
      results.push({icon: 'envelope', key: 'warning'});
    }

    if(topic.get('bookmarked')){
      var url = topic.get('url');
      var postNumbers = topic.get('bookmarked_post_numbers');
      var extraClasses = "";
      if(postNumbers && postNumbers[0] > 1) {
        url += '/' + postNumbers[0];
      } else {
        extraClasses = "op-bookmark";
      }

      results.push({extraClasses: extraClasses, icon: 'bookmark', key: 'bookmarked', href: url});
    }

    if (topic.get('closed') && topic.get('archived')) {
      results.push({icon: 'lock', key: 'locked_and_archived'});
    } else if(topic.get('closed')){
      results.push({icon: 'lock', key: 'locked'});
    } else if(topic.get('archived')){
      results.push({icon: 'lock', key: 'archived'});
    }

    if(topic.get('pinned')){
      results.push({icon: 'thumb-tack', key: 'pinned'});
    }

    if(topic.get('unpinned')){
      results.push({icon: 'thumb-tack unpinned', key: 'unpinned'});
    }

    if(topic.get('invisible')){
      results.push({icon: 'eye-slash', key: 'invisible'});
    }

    _.each(results, function(result){
      result.title = I18n.t("topic_statuses." + result.key + ".help");
      if(!self.disableActions && (result.key === "pinned" ||result.key === "unpinned")){
        result.openTag = 'a href';
        result.closeTag = 'a';
      } else {
        result.openTag = 'span';
        result.closeTag = 'span';
      }
    });

    return results;
  }.property()
});

