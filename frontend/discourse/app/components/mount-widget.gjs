/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import deprecated from "discourse/lib/deprecated";

export default class MountWidget extends Component {
  init() {
    super.init(...arguments);

    deprecated(
      "`The `MountWidget` component has been decommissioned. Your site may not work properly. See https://meta.discourse.org/t/375332/1"
    );
  }

  <template>{{! no-op }}</template>
}
