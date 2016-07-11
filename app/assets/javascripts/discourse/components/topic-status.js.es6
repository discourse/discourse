import { iconHTML } from 'discourse/helpers/fa-icon';
import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  classNames: ['topic-statuses'],

  rerenderTriggers: ['topic.archived', 'topic.closed', 'topic.pinned', 'topic.visible', 'topic.unpinned', 'topic.is_warning'],

  click(e) {
    if ($(e.target).hasClass('fa-thumb-tack')) {
      const topic = this.get('topic');

      // only pin unpin for now
      if (topic.get('pinned')) {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }

    return false;
  },

  canAct: function() {
    return Discourse.User.current() && !this.get('disableActions');
  }.property('disableActions'),

  statuses: function() {
    const results = [];

    const addStatus = (name, key, actionable) => {
      results.push({
        name: name,
        key: `topic_statuses.${key}.help`,
        actionable: actionable
      });
    };

    const addStatusIf = (conditionProp, name, key, actionable) => {
      if (!this.get(conditionProp)) {
        return;
      }
      addStatus(name, key, actionable);
    };

    addStatusIf('topic.is_warning', 'envelope', 'warning');

    if (this.get('topic.closed') && this.get('topic.archived')) {
      addStatus('lock', 'locked_and_archived');
    } else {
      addStatusIf('topic.closed', 'lock', 'locked');
      addStatusIf('topic.archived', 'lock', 'archived');
    }

    addStatusIf('topic.pinned', 'thumb-tack', 'pinned', this.get("canAct"));
    addStatusIf('topic.unpinned', 'thumb-tack', 'unpinned', this.get("canAct"));
    addStatusIf('topic.invisible', 'eye-slash', 'invisible');

    return results;
  }.property(),

  renderString(buffer) {
    _.each(this.get('statuses'), (status) => {
      const title = Discourse.Utilities.escapeExpression(I18n.t(status.key)),
            startTag = status.actionable ? "a href" : "span",
            endTag = status.actionable ? "a" : "span",
            iconArgs = status.key === 'unpinned' ? { 'class': 'unpinned' } : null,
            icon = iconHTML(status.name, iconArgs);

      buffer.push(`<${startTag} title='${title}' class='topic-status'>${icon}</${endTag}>`);
    });
  }
});
