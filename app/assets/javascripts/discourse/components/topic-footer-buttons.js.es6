import ContainerView from 'discourse/views/container';

export default ContainerView.extend({
  elementId: 'topic-footer-buttons',

  init() {
    this._super();

    if (this.currentUser) {
      const viewArgs = this.getProperties('topic', 'topicDelegated');
      viewArgs.currentUser = this.currentUser;

      this.attachViewWithArgs(viewArgs, 'topic-footer-main-buttons');
      this.attachViewWithArgs(viewArgs, 'pinned-button');
      this.attachViewWithArgs(viewArgs, 'topic-notifications-button');

      this.trigger('additionalButtons', this);
    } else {
      // If not logged in give them a login control
      this.attachViewClass('login-reply-button');
    }
  }
});
