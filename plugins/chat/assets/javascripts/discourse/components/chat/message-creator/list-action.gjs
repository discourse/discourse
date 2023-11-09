import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class ListAction extends Component {
  <template>
    <DButton
      class="btn btn-flat"
      @icon={{@item.icon}}
      @translatedLabel={{@item.label}}
    />
  </template>
}
