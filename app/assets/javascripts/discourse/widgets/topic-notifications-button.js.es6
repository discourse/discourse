import { createWidget } from 'discourse/widgets/widget';
import { topicLevels, buttonDetails } from 'discourse/lib/notification-levels';
import { h } from 'virtual-dom';
import RawHTML from 'discourse/widgets/raw-html';

createWidget('notification-option', {
  buildKey: attrs => `topic-notifications-button-${attrs.id}`,
  tagName: 'li',

  html(attrs) {
    return h('a', [
        h('span.icon', { className: `fa fa-${attrs.icon} ${attrs.key}`}),
        h('div', [
          h('span.title', I18n.t(`topic.notifications.${attrs.key}.title`)),
          h('span.desc', I18n.t(`topic.notifications.${attrs.key}.description`)),
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

  buildAttributes() {
    return { title: I18n.t('topic.notifications.title') };
  },

  buttonFor(level) {
    const details = buttonDetails(level);

    const button = {
      className: `btn`,
      label: null,
      icon: details.icon,
      action: 'toggleDropdown',
      iconClass: details.key
    };

    if (this.attrs.showFullTitle) {
      button.label = `topic.notifications.${details.key}.title`;
    } else {
      button.className = 'btn notifications-dropdown';
    }

    return this.attach('button', button);
  },

  html(attrs, state) {
    const details = attrs.topic.get('details');
    const result = [ this.buttonFor(details.get('notification_level')) ];

    if (state.expanded) {
      result.push(h('ul.dropdown-menu', topicLevels.map(l => this.attach('notification-option', l))));
    }

    if (attrs.appendReason) {
      result.push(new RawHTML({ html: `<p>${details.get('notificationReasonText')}</p>` }));
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
  },

  topicNotificationsButtonChanged(msg) {
    switch(msg.type) {
      case 'notification':
        this.notificationLevelChanged(msg.id);
        break;
    }
  }
});
