import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default class HighlightedCode extends Component {
  @service session;
  @service siteSettings;

  highlight = modifier((element) => {
    debugger;
    highlightSyntax(element, this.siteSettings, this.session);
  });

  <template>
    <pre
      {{! pass in the args to re-highlight if they change }}
      {{this.highlight @code @lang}}
    ><code class="lang-{{@lang}}">{{@code}}</code></pre>
  </template>
}
