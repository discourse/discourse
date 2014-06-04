/**
  This view is for rendering an icon representing the status of a topic

  @class TopicStatusComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
export default Ember.Component.extend({
  classNames: ['topic-statuses'],

  hasDisplayableStatus: Em.computed.or('topic.archived','topic.closed', 'topic.pinned', 'topic.unpinned', 'topic.invisible', 'topic.archetypeObject.notDefault'),
  shouldRerender: Discourse.View.renderIfChanged('topic.archived','topic.closed', 'topic.pinned', 'topic.visible', 'topic.unpinned'),

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

  render: function(buffer) {
    if (!this.get('hasDisplayableStatus')) { return; }

    var self = this,
        renderIconIf = function(conditionProp, name, key, actionable) {
      if (!self.get(conditionProp)) { return; }
      var title = I18n.t("topic_statuses." + key + ".help");

      var startTag = actionable ? "a href='#'" : "span";
      var endTag = actionable ? "a" : "span";

      buffer.push("<" + startTag +
        " title='" + title +"' class='topic-status'><i class='fa fa-" + name + "'></i></" + endTag + ">");
    };

    // Allow a plugin to add a custom icon to a topic
    this.trigger('addCustomIcon', buffer);

    var togglePin = function(){

    };

    renderIconIf('topic.closed', 'lock', 'locked');
    renderIconIf('topic.archived', 'lock', 'archived');
    renderIconIf('topic.pinned', 'thumb-tack', 'pinned', togglePin);
    renderIconIf('topic.unpinned', 'thumb-tack unpinned', 'unpinned', togglePin);
    renderIconIf('topic.invisible', 'eye-slash', 'invisible');
  }
});
