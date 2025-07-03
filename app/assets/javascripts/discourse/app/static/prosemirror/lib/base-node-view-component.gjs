import Component from "@glimmer/component";

/**
 * Base component class for ProseMirror NodeView components
 *
 * Automatically registers itself with the NodeView on construction
 * and provides access to common NodeView properties.
 */
export default class BaseNodeViewComponent extends Component {
  constructor() {
    super(...arguments);

    this.args.nodeView.setComponentInstance(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.args.nodeView.setComponentInstance(null);
  }

  get node() {
    return this.args.node;
  }

  get view() {
    return this.args.view;
  }

  get getPos() {
    return this.args.getPos;
  }

  get dom() {
    return this.args.dom;
  }

  get nodeView() {
    return this.args.nodeView;
  }
}
