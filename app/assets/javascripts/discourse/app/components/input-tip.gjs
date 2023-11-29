import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class InputTip extends Component {
  get tipIcon() {
    return iconHTML(this.args.validation.failed ? "times" : "check");
  }

  <template>
    <div class="tip {{if @validation.failed 'bad' 'good'}}">
      {{#if @validation.reason}}
        {{htmlSafe this.tipIcon}}
        {{@validation.reason}}
      {{/if}}
    </div>
  </template>
}
