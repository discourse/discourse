import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import highlightSyntax from "discourse/lib/highlight-syntax";
import type Session from "discourse/models/session";
import type SiteSettingsService from "discourse/services/site-settings";

interface DHighlightedCodeSignature {
  Args: {
    /** The code to show. */
    code: string;

    /** The language to highlight the code as, or `auto` to detect it. */
    lang: string;
  };
}

export default class DHighlightedCode extends Component<DHighlightedCodeSignature> {
  @service declare session: Session;
  @service declare siteSettings: SiteSettingsService;

  /**
   * The cast is needed because the modifier types reject an async callback, though its
   * promise is ignored like any other value that is not a teardown function.
   */
  highlight = modifier((async (element: HTMLDivElement) => {
    const code = document.createElement("code");
    code.classList.add(`lang-${this.args.lang}`);
    code.textContent = this.args.code;

    const pre = document.createElement("pre");
    pre.appendChild(code);

    element.replaceChildren(pre);
    await highlightSyntax(pre, this.siteSettings, this.session);
  }) as (element: HTMLDivElement) => void);

  <template>
    <div {{this.highlight}}></div>
  </template>
}
