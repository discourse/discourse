import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import { modifier } from "ember-modifier";
import highlightSyntax from "discourse/lib/highlight-syntax";
import SessionService from "discourse/services/session";
import SiteSettingsService from "discourse/services/site-settings";

export default class DHighlightedCode extends Component {
  @service(() => SessionService) session;
  @service(() => SiteSettingsService) siteSettings;

  highlight = modifier(async (element) => {
    const code = document.createElement("code");
    code.classList.add(`lang-${this.args.lang}`);
    code.textContent = this.args.code;

    const pre = document.createElement("pre");
    pre.appendChild(code);

    element.replaceChildren(pre);
    await highlightSyntax(pre, this.siteSettings, this.session);
  });

  <template>
    <div {{this.highlight}}></div>
  </template>
}
