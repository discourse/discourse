import Component from "@ember/component";

export default class TranslationComponent extends Component {
  tagName = "span";
  classNames = ["i18n-component-placeholder"];
  attributeBindings = ["data-placeholder-name:name"];

  didInsertElement() {
    super.didInsertElement(...arguments);

    // Find the right location in the translation and move this component there
    const container = this.element.closest(".i18n-container");
    if (!container) {
      return;
    }

    const placeholderText = `<${this.name}>`;

    for (const node of container.childNodes) {
      if (node.nodeType !== Node.TEXT_NODE) {
        continue;
      }
      const text = node.nodeValue;
      if (text.includes(placeholderText)) {
        const [before, after] = text.split(placeholderText);

        if (before) {
          const beforeNode = document.createTextNode(before);
          node.parentNode.insertBefore(beforeNode, node);
        }

        node.parentNode.insertBefore(this.element, node);

        if (after) {
          const afterNode = document.createTextNode(after);
          node.parentNode.insertBefore(afterNode, node);
        }

        node.parentNode.removeChild(node);
        break;
      }
    }
  }
}
