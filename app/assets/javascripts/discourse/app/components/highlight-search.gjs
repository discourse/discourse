import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightSearch extends Component {
  highlight = modifier((element) => {
    // Clear any existing highlights within this element first
    element
      .querySelectorAll("span.search-highlight")
      .forEach((highlightElement) => {
        const parentNode = highlightElement.parentNode;
        parentNode.replaceChild(highlightElement.firstChild, highlightElement);
        parentNode.normalize();
      });

    // Apply new highlights
    highlightSearch(element, this.args.highlight, {
      partialMatch: this.args.partialMatch ?? false,
    });
  });

  <template>
    <span {{this.highlight}}>{{yield}}</span>
  </template>
}
