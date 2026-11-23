import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";

/**
 * The live element of one announcement. It is added empty and given its text a run-loop turn
 * later, because text that arrives together with its live element is not reliably read.
 */
class LiveMessage extends Component {
  @tracked filled = false;

  fillLater = modifier(() => {
    const timer = next(() => (this.filled = true));
    return () => cancel(timer);
  });

  <template>
    <div
      aria-atomic="true"
      aria-live={{@live}}
      role={{@role}}
      {{this.fillLater}}
    >
      {{~if this.filled @text~}}
    </div>
  </template>
}

/**
 * A live region that renders every write in a new element, keyed on the write count. VoiceOver
 * stays silent when an element is given the text it last said, even if it was emptied in
 * between, so one long-lived element would swallow every repeat. The id sits on a wrapper that
 * is not itself live. Idle elements hold nothing: an idle character is read aloud whenever a
 * message clears.
 */
const LiveRegion = <template>
  <div class="sr-only" id={{@id}}>
    {{#each (array @writeCount)}}
      <LiveMessage @live={{@live}} @role={{@role}} @text={{@text}} />
    {{/each}}
  </div>
</template>;

export default class A11yLiveRegions extends Component {
  @service a11y;

  get assertiveWriteCount() {
    return this.a11y.liveRegionWriteCount("assertive");
  }

  get politeWriteCount() {
    return this.a11y.liveRegionWriteCount("polite");
  }

  <template>
    <LiveRegion
      @id="a11y-announcements-polite"
      @live="polite"
      @role="status"
      @text={{this.a11y.politeMessage}}
      @writeCount={{this.politeWriteCount}}
    />
    <LiveRegion
      @id="a11y-announcements-assertive"
      @live="assertive"
      @role="alert"
      @text={{this.a11y.assertiveMessage}}
      @writeCount={{this.assertiveWriteCount}}
    />
  </template>
}
