import Connector from 'discourse/widgets/connector';
import { h } from 'virtual-dom';
import PostCooked from 'discourse/widgets/post-cooked';
import RawHtml from 'discourse/widgets/raw-html';

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

  rawHtml(html) {
    return new RawHtml({ html });
  }

  cooked(cooked) {
    return new PostCooked({ cooked });
  }
}
DecoratorHelper.prototype.h = h;

export default DecoratorHelper;
