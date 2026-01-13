import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RewindHeader extends Component {
  @service rewind;

  <template>
    <div class="rewind__header">
      <div class="rewind__header-logo">
        {{icon "repeat"}}
        <div class="rewind__header-title">
          {{i18n "discourse_rewind.title"}}
        </div>
        <div class="rewind__header-year">
          {{this.rewind.fetchRewindYear}}
        </div>
      </div>
    </div>
  </template>
}
