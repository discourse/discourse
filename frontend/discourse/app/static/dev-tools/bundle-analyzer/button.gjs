import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BundleAnalyzerModal from "./modal";

export default class BundleAnalyzerButton extends Component {
  @service modal;

  @action
  show() {
    this.modal.show(BundleAnalyzerModal);
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
