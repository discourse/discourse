import ButtonView from 'discourse/views/button';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default ButtonView.extend({
  textKey: 'topic.invite_reply.title',
  helpKey: 'topic.invite_reply.help',
  attributeBindings: ['disabled'],
  disabled: Em.computed.or('controller.model.archived', 'controller.model.closed', 'controller.model.deleted'),

  renderIcon(buffer) {
    buffer.push(iconHTML('users'));
  },

  click() {
    this.get('controller').send('showInvite');
  }
});
