import { createWidget, applyDecorators } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

createWidget('admin-menu-button', {
  html(attrs) {
    let className = 'btn';
    if (attrs.buttonClass) { className += ' ' + attrs.buttonClass; }

    return h('li', { className: attrs.className }, this.attach('button', {
      className,
      action: attrs.action,
      icon: attrs.icon,
      label: `topic.${attrs.label}`,
      secondaryAction: 'hideAdminMenu'
    }));
  }
});

createWidget('topic-admin-menu-button', {
  tagName: 'span',
  buildKey: () => `topic-admin-menu-button`,

  defaultState() {
    return { expanded: false, position: null };
  },

  html(attrs, state) {
    if (!this.currentUser || !this.currentUser.get('canManageTopic')) { return; }

    const result = [];
    result.push(this.attach('button', {
      className: 'btn no-text' + (attrs.fixed ? " show-topic-admin" : ""),
      title: 'topic_admin_menu',
      icon: 'wrench',
      action: 'showAdminMenu',
      sendActionEvent: true
    }));

    if (state.expanded) {
      result.push(this.attach('topic-admin-menu', { position: state.position,
                                                    fixed: attrs.fixed,
                                                    topic: attrs.topic,
                                                    openUpwards: attrs.openUpwards }));
    }

    return result;
  },

  hideAdminMenu() {
    this.state.expanded = false;
    this.state.position = null;
  },

  showAdminMenu(e) {
    this.state.expanded = true;

    const $button = $(e.target).closest('button');
    const position = $button.position();
    position.left = position.left;

    if (this.attrs.fixed) {
      position.left += $button.width() - 203;
    }
    this.state.position = position;
  }
});

export default createWidget('topic-admin-menu', {
  tagName: 'div.popup-menu.topic-admin-popup-menu',

  buildAttributes(attrs) {
    const { top, left } = attrs.position;
    const position = attrs.fixed ? 'fixed' : 'absolute';

    if (attrs.openUpwards) {
      const bottom = $(document).height() - top;
      return { style: `position: ${position}; bottom: ${bottom}px; left: ${left}px;` };
    } else {
      return { style: `position: ${position}; top: ${top}px; left: ${left}px;` };
    }
  },

  html(attrs) {
    const buttons = [];
    buttons.push({ className: 'topic-admin-multi-select',
                   action: 'toggleMultiSelect',
                   icon: 'tasks',
                   label: 'actions.multi_select' });

    const topic = attrs.topic;
    const details = topic.get('details');
    if (details.get('can_delete')) {
      buttons.push({ className: 'topic-admin-delete',
                     buttonClass: 'btn-danger',
                     action: 'deleteTopic',
                     icon: 'trash-o',
                     label: 'actions.delete' });
    }

    if (topic.get('deleted') && details.get('can_recover')) {
      buttons.push({ className: 'topic-admin-recover',
                     action: 'recoverTopic',
                     icon: 'undo',
                     label: 'actions.recover' });
    }

    if (topic.get('closed')) {
      buttons.push({ className: 'topic-admin-open',
                     action: 'toggleClosed',
                     icon: 'unlock',
                     label: 'actions.open' });
    } else {
      buttons.push({ className: 'topic-admin-close',
                     action: 'toggleClosed',
                     icon: 'lock',
                     label: 'actions.close' });
      buttons.push({ className: 'topic-admin-autoclose',
                     action: 'showAutoClose',
                     icon: 'clock-o',
                     label: 'actions.auto_close' });
    }

    const isPrivateMessage = topic.get('isPrivateMessage');

    if (!isPrivateMessage && topic.get('visible')) {
      const featured = topic.get('pinned_at') || topic.get('isBanner');
      buttons.push({ className: 'topic-admin-pin',
                     action: 'showFeatureTopic',
                     icon: 'thumb-tack',
                     label: featured ? 'actions.unpin' : 'actions.pin' });
    }
    buttons.push({ className: 'topic-admin-change-timestamp',
                   action: 'showChangeTimestamp',
                   icon: 'calendar',
                   label: 'change_timestamp.title' });

    if (!isPrivateMessage) {
      buttons.push({ className: 'topic-admin-archive',
                     action: 'toggleArchived',
                     icon: 'folder',
                     label: topic.get('archived') ? 'actions.unarchive' : 'actions.archive' });
    }

    const visible = topic.get('visible');
    buttons.push({ className: 'topic-admin-visible',
                   action: 'toggleVisibility',
                   icon: visible ? 'eye' : 'eye-slash',
                   label: visible ? 'actions.invisible' : 'actions.visible' });

    if (this.currentUser.get('staff')) {
      buttons.push({ className: 'topic-admin-convert',
                     action: isPrivateMessage ? 'convertToPublicTopic' : 'convertToPrivateMessage',
                     icon: isPrivateMessage ? 'comment' : 'envelope',
                     label: isPrivateMessage ? 'actions.make_public' : 'actions.make_private' });
    }

    const extraButtons = applyDecorators(this, 'adminMenuButtons', this.attrs, this.state);

    return [ h('h3', I18n.t('admin_title')),
             h('ul', buttons.concat(extraButtons).map(b => this.attach('admin-menu-button', b))) ];
  },

  clickOutside() {
    this.sendWidgetAction('hideAdminMenu');
  }
});
