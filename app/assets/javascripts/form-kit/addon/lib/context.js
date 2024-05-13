export default class Context {
  static defaults = {
    horizontal: false,
    size: 12,
  };

  constructor(node) {
    this.node = node;
  }

  get horizontal() {
    return this.#walkTreeUp(this.node, "horizontal");
  }

  get size() {
    return this.#walkTreeUp(this.node, "size");
  }

  #walkTreeUp(node, property) {
    while (node) {
      if (property === "horizontal" && node.type === "group") {
        console.log("while", property, node.props, node.props[property]);
      }

      if (node.props[property]) {
        return true;
      }

      console.log(node.parent);

      node = node.parent;
    }

    return Context.defaults[property];
  }
}
