import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import ModalService from "discourse/services/modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class BundleAnalyzerButton extends Component {
  @service(() => ModalService) modal;

  @action
  show() {
    this.modal.show(() => import("./modal"));
  }

  <template>
    <button
      class="bundle-analyzer-button"
      title={{i18n "dev_tools.toggle_bundle_analyzer"}}
      type="button"
      {{on "click" this.show}}
    >
      {{dIcon "chart-column"}}
    </button>
  </template>
}
