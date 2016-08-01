import ButtonView from 'discourse/views/button';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default ButtonView.extend({
  classNames: ['print'],
  textKey: 'topic.print.title',
  helpKey: 'topic.print.help',

  renderIcon(buffer) {
    buffer.push(iconHTML("print"));
  },

  click() {
    window.open(this.get('controller.model.printUrl'), '', 'menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=315');
  }
});
