import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import BundleAnalyzerModal from "./components/modal.gjs";

export default class BundleAnalyzerButton extends Component {
  @service modal;

  @action
  show() {
    this.modal.show(BundleAnalyzerModal);
  }

  <template>
    <button
      class="bundle-analyzer-button"
      title="Bundle analyzer"
      type="button"
      {{on "click" this.show}}
    >
      {{dIcon "chart-column"}}
    </button>
  </template>
}
