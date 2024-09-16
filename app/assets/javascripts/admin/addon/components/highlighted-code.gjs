import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default class HighlightedCode extends Component {
  @service session;
  @service siteSettings;

  highlight = modifier(async (element) => {
    const code = document.createElement("code");
    code.classList.add(`lang-${this.args.lang}`);
    code.textContent = this.args.code;

    const pre = document.createElement("pre");
    pre.appendChild(code);

    await highlightSyntax(pre, this.siteSettings, this.session);

    element.replaceChildren(pre);
  });

  <template>
    <div {{this.highlight}}></div>
  </template>
}
