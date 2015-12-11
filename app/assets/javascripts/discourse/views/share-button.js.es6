import ButtonView from 'discourse/views/button';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default ButtonView.extend({
  classNames: ['share'],
  textKey: 'topic.share.title',
  helpKey: 'topic.share.help',
  'data-share-url': Em.computed.alias('topic.shareUrl'),
  topic: Em.computed.alias('controller.model'),

  renderIcon(buffer) {
    buffer.push(iconHTML("link"));
  }
});
