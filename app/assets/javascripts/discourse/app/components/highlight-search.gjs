import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightSearch extends Component {
  highlight = modifier((element) => {
    highlightSearch(element, this.args.highlight);
  });

  <template>
    <span {{this.highlight}}>{{yield}}</span>
  </template>
}
