import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Disclosure extends Component {
  get lines() {
    const disclosure = this.args.disclosure;
    if (!disclosure) {
      return [];
    }

    const lines = (disclosure.externalCalls ?? []).map((call) =>
      i18n(
        call.replayed
          ? "discourse_workflows.tests.disclosure.external_replayed"
          : "discourse_workflows.tests.disclosure.external_not_previewed",
        { step: call.name }
      )
    );
    if (disclosure.pinnedSteps?.length) {
      lines.push(
        i18n("discourse_workflows.tests.disclosure.pinned", {
          steps: disclosure.pinnedSteps.join(", "),
        })
      );
    }
    if (disclosure.unsupportedSteps?.length) {
      lines.push(
        i18n("discourse_workflows.tests.disclosure.unsupported", {
          steps: disclosure.unsupportedSteps.join(", "),
        })
      );
    }
    if (disclosure.liveActors) {
      lines.push(i18n("discourse_workflows.tests.disclosure.live_actors"));
    }
    return lines;
  }

  <template>
    {{#if this.lines.length}}
      <ul class="workflows-test-disclosure" ...attributes>
        {{#each this.lines as |line|}}
          <li class="workflows-test-disclosure__line">
            {{dIcon "circle-info"}}
            {{line}}
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </template>
}
