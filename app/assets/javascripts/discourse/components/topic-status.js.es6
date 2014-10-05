/**
  This view is for rendering an icon representing the status of a topic

  @class TopicStatusComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
export default Ember.Component.extend({
  classNames: ['topic-statuses'],

  hasDisplayableStatus: Em.computed.or('topic.archived','topic.closed', 'topic.pinned', 'topic.unpinned', 'topic.invisible', 'topic.archetypeObject.notDefault', 'topic.is_warning'),
  shouldRerender: Discourse.View.renderIfChanged('topic.archived', 'topic.closed', 'topic.pinned', 'topic.visible', 'topic.unpinned', 'topic.is_warning'),

  didInsertElement: function(){
    var self = this;

    this.$('a').click(function(){
      var topic = self.get('topic');

      // only pin unpin for now
      if (topic.get('pinned')) {
        topic.clearPin();
      } else {
        topic.rePin();
      }

      return false;
    });
  },

  canAct: function() {
    return Discourse.User.current() && !this.get('disableActions');
  }.property('disableActions'),

  render: function(buffer) {
    if (!this.get('hasDisplayableStatus')) { return; }

    var self = this;

    var renderIconIf = function(conditionProp, name, key, actionable) {
      if (!self.get(conditionProp)) { return; }
      var title = I18n.t("topic_statuses." + key + ".help");

      var startTag = actionable ? "a href='#'" : "span";
      var endTag = actionable ? "a" : "span";

      buffer.push("<" + startTag +
        " title='" + title +"' class='topic-status'><i class='fa fa-" + name + "'></i></" + endTag + ">");
    };

    // Allow a plugin to add a custom icon to a topic
    this.trigger('addCustomIcon', buffer);

    renderIconIf('topic.is_warning', 'envelope', 'warning');
    renderIconIf('topic.closed', 'lock', 'locked');
    renderIconIf('topic.archived', 'lock', 'archived');
    renderIconIf('topic.pinned', 'thumb-tack', 'pinned', self.get("canAct") );
    renderIconIf('topic.unpinned', 'thumb-tack unpinned', 'unpinned', self.get("canAct"));
    renderIconIf('topic.invisible', 'eye-slash', 'invisible');
  }
});
