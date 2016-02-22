import Connector from 'discourse/widgets/connector';
import { h } from 'virtual-dom';

class DecoratorHelper {
  constructor(widget, attrs, state) {
    this.widget = widget;
    this.attrs = attrs;
    this.state = state;
  }

  connect(details) {
    return new Connector(this.widget, details);
  }

  getModel() {
    return this.widget.findAncestorModel();
  }
}
DecoratorHelper.prototype.h = h;

export default DecoratorHelper;
