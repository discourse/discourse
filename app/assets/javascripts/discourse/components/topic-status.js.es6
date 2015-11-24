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

  renderString(buffer) {
    const self = this;

    const renderIcon = function(name, key, actionable) {
      const title = Discourse.Utilities.escapeExpression(I18n.t(`topic_statuses.${key}.help`)),
            startTag = actionable ? "a href" : "span",
            endTag = actionable ? "a" : "span",
            iconArgs = key === 'unpinned' ? { 'class': 'unpinned' } : null,
            icon = iconHTML(name, iconArgs);

      buffer.push(`<${startTag} title='${title}' class='topic-status'>${icon}</${endTag}>`);
    };

    const renderIconIf = function(conditionProp, name, key, actionable) {
      if (!self.get(conditionProp)) { return; }
      renderIcon(name, key, actionable);
    };

    renderIconIf('topic.is_warning', 'envelope', 'warning');

    if (this.get('topic.closed') && this.get('topic.archived')) {
      renderIcon('lock', 'locked_and_archived');
    } else {
      renderIconIf('topic.closed', 'lock', 'locked');
      renderIconIf('topic.archived', 'lock', 'archived');
    }

    renderIconIf('topic.pinned', 'thumb-tack', 'pinned', this.get("canAct") );
    renderIconIf('topic.unpinned', 'thumb-tack', 'unpinned', this.get("canAct"));
    renderIconIf('topic.invisible', 'eye-slash', 'invisible');
  }
});
