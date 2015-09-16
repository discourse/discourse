import ContainerView from 'discourse/views/container';
import { on } from 'ember-addons/ember-computed-decorators';

export default ContainerView.extend({
  elementId: 'topic-footer-buttons',

  @on('init')
  createButtons() {
    const topic = this.get('topic');
    const currentUser = this.get('controller.currentUser');

    if (currentUser) {
      const viewArgs = { topic, currentUser };
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
