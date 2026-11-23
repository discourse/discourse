import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { service } from "@ember/service";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";

/**
 * A region of two slots that take turns holding its message. Idle slots hold nothing: an idle
 * character would be read aloud whenever a message clears.
 */
const LiveRegion = <template>
  <div class="sr-only" id={{@id}}>
    <div aria-atomic="true" aria-live={{@live}} role={{@role}}>
      {{get @slots "0"}}
    </div>
    <div aria-atomic="true" aria-live={{@live}} role={{@role}}>
      {{get @slots "1"}}
    </div>
  </div>
</template>;

export default class A11yLiveRegions extends Component {
  @service a11y;

  get assertiveSlots() {
    return this.a11y.liveRegionSlots("assertive");
  }

  get atRoot() {
    return !this.a11y.liveRegionOutlet;
  }

  get politeSlots() {
    return this.a11y.liveRegionSlots("polite");
  }

  <template>
    <DConditionalInElement
      @append={{true}}
      @element={{this.a11y.liveRegionOutlet}}
      @inline={{this.atRoot}}
    >
      <LiveRegion
        @id="a11y-announcements-polite"
        @live="polite"
        @role="status"
        @slots={{this.politeSlots}}
      />
      <LiveRegion
        @id="a11y-announcements-assertive"
        @live="assertive"
        @role="alert"
        @slots={{this.assertiveSlots}}
      />
    </DConditionalInElement>
  </template>
}
