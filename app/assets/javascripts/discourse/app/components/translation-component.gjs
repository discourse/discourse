import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class TranslationComponent extends Component {
  @action
  didInsert(element) {
    // Find the right location in the translation and move this component there
    const container = element.closest(".i18n-container");
    if (!container) {
      return;
    }

    const placeholderText = `<${this.args.name}>`;

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

        node.parentNode.insertBefore(element, node);

        if (after) {
          const afterNode = document.createTextNode(after);
          node.parentNode.insertBefore(afterNode, node);
        }

        node.parentNode.removeChild(node);
        break;
      }
    }
  }

  <template>
    <span
      class="i18n-component-placeholder"
      data-placeholder-name={{@name}}
      {{didInsert this.didInsert}}
    >
      {{yield}}
    </span>
  </template>
}
