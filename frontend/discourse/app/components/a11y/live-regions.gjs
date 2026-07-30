import Component from "@glimmer/component";
import { service } from "@ember/service";

/**
 * What the regions hold when there is nothing to say.
 *
 * A live region speaks when its text *changes*, and an empty one is not a reliable starting
 * point: announcing the same message twice in a row is inaudible on VoiceOver even though the
 * region is blanked and rewritten in between, because the text it ends up with is the text it
 * already had. Idling on a non-breaking space makes every transition a change between two
 * non-empty strings, which does get read — so a reader who keeps typing a query that keeps
 * matching nothing hears the outcome each time rather than once.
 *
 * A non-breaking space renders invisibly and is not announced on its own. Deliberately applied
 * here and not in the service, whose messages are the values callers compare announcements
 * against: a placeholder there makes "nothing is being announced" indistinguishable from a real
 * message, and every such comparison silently stops matching.
 *
 * Exported so a test asserting that a region said nothing can name this rather than spell out an
 * invisible character.
 */
export const IDLE_ANNOUNCEMENT = "\u00a0"; // non-breaking space

export default class A11yLiveRegions extends Component {
  @service a11y;

  get assertiveMessage() {
    return this.a11y.assertiveMessage || IDLE_ANNOUNCEMENT;
  }

  get politeMessage() {
    return this.a11y.politeMessage || IDLE_ANNOUNCEMENT;
  }

  <template>
    <div
      id="a11y-announcements-polite"
      class="sr-only"
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      {{this.politeMessage}}
    </div>
    <div
      id="a11y-announcements-assertive"
      class="sr-only"
      role="alert"
      aria-live="assertive"
      aria-atomic="true"
    >
      {{this.assertiveMessage}}
    </div>
  </template>
}
