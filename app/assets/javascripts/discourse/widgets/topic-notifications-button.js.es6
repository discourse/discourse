import { createWidget } from 'discourse/widgets/widget';
import { all, buttonDetails } from 'discourse/lib/notification-levels';
import { h } from 'virtual-dom';

createWidget('notification-option', {
  buildKey: attrs => `topic-notifications-button-${attrs.id}`,
  tagName: 'li',

  html(attrs) {
    return h('a', [
        h('span.icon', { className: `fa fa-${attrs.icon} ${attrs.key}`}),
        h('div', [
          h('span.title', I18n.t(`topic.notifications.${attrs.key}.title`)),
          h('span', I18n.t(`topic.notifications.${attrs.key}.description`)),
        ])
    ]);
  },

  click() {
    this.sendWidgetAction('notificationLevelChanged', this.attrs.id);
  }
});

export default createWidget('topic-notifications-button', {
  tagName: 'span.btn-group.notification-options',
  buildKey: () => `topic-notifications-button`,

  defaultState() {
    return { expanded: false };
  },

  buildClasses(attrs, state) {
    if (state.expanded) { return "open"; }
  },

  buttonFor(level) {
    const details = buttonDetails(level);
    return this.attach('button', {
      className: `btn no-text`,
      icon: details.icon,
      action: 'toggleDropdown',
      iconClass: details.key
    });
  },

  html(attrs, state) {
    const result = [ this.buttonFor(attrs.topic.get('details.notification_level')) ];
    if (state.expanded) {
      result.push(h('ul.dropdown-menu', all.map(l => this.attach('notification-option', l))));
    }

    return result;
  },

  toggleDropdown() {
    this.state.expanded = !this.state.expanded;
  },

  clickOutside() {
    if (this.state.expanded) {
      this.sendWidgetAction('toggleDropdown');
    }
  },

  notificationLevelChanged(id) {
    this.state.expanded = false;
    return this.attrs.topic.get('details').updateNotifications(id);
  }
});
