import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class A11yLiveRegions extends Component {
  @service a11y;

  <template>
    <div
      id="a11y-announcements-polite"
      class="sr-only"
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      {{this.a11y.politeMessage}}
    </div>
    <div
      id="a11y-announcements-assertive"
      class="sr-only"
      role="alert"
      aria-live="assertive"
      aria-atomic="true"
    >
      {{this.a11y.assertiveMessage}}
    </div>
  </template>
}
