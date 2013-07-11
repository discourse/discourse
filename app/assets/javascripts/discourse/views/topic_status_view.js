/**
  This view is for rendering an icon representing the status of a topic

  @class TopicStatusView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicStatusView = Discourse.View.extend({
  classNames: ['topic-statuses'],

  hasDisplayableStatus: Em.computed.or('topic.closed', 'topic.pinned', 'topic.invisible', 'topic.archetypeObject.notDefault'),
  shouldRerender: Discourse.View.renderIfChanged('topic.closed', 'topic.pinned', 'topic.visible'),

  render: function(buffer) {
    if (!this.get('hasDisplayableStatus')) { return; }

    var topicStatusView = this;
    var renderIconIf = function(conditionProp, name, key) {
      if (!topicStatusView.get(conditionProp)) { return; }
      var title = I18n.t("topic_statuses." + key + ".help");
      buffer.push("<span title='" + title + "' class='topic-status'><i class='icon icon-" + name + "'></i></span>");
    };

    // Allow a plugin to add a custom icon to a topic
    this.trigger('addCustomIcon', buffer);

    renderIconIf('topic.closed', 'lock', 'locked');
    renderIconIf('topic.pinned', 'pushpin', 'pinned');
    renderIconIf('topic.invisible', 'eye-close', 'invisible');
  }
});


Discourse.View.registerHelper('topicStatus', Discourse.TopicStatusView);
