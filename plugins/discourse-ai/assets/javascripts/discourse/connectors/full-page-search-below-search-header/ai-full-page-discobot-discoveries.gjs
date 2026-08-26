import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiFullPageDiscobotDiscoveries extends Component {
  // Parked: the search menu offers asking as one of several options now, and
  // full-page search has no equivalent yet. Its only gate was the mode the
  // toggle used to set, so leaving it on would mean asking on every full-page
  // search with no way to decline. Returning false here keeps the component
  // unmounted, so neither the credit check nor the discovery request is sent.
  static shouldRender() {
    return false;
  }

  @service aiCredits;
  @service discobotDiscoveries;

  @tracked creditsAvailable = true;
  @tracked creditCheckComplete = false;

  constructor() {
    super(...arguments);
    this.#checkCredits();
  }

  async #checkCredits() {
    try {
      this.creditsAvailable =
        await this.aiCredits.isFeatureCreditAvailable("discoveries");
    } catch {
      this.creditsAvailable = true;
    }
    this.creditCheckComplete = true;
  }

  get shouldShow() {
    return (
      this.creditCheckComplete &&
      this.creditsAvailable &&
      this.discobotDiscoveries.mode === "ask"
    );
  }

  get hasContent() {
    return this.discobotDiscoveries.showDiscoveryTitle;
  }

  <template>
    {{#if this.shouldShow}}
      {{#if this.hasContent}}
        {{bodyClass "has-discoveries"}}
      {{/if}}
      <div
        class={{dConcatClass
          "ai-search-discoveries__discoveries-wrapper"
          (if this.hasContent "--has-content")
        }}
      >
        <div class="full-page-discoveries">
          <AiSearchDiscoveries
            @searchTerm={{@outletArgs.search}}
            @showHeading={{true}}
            @fullPage={{true}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
