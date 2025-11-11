import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class ShowUserNotes extends Component {
  get label() {
    if (this.args.count > 0) {
      return i18n("user_notes.show", { count: this.args.count });
    } else {
      return i18n("user_notes.title");
    }
  }

  <template>
    <DButton
      class="btn-default show-user-notes-btn"
      @action={{@show}}
      @icon="pen-to-square"
      @translatedLabel={{this.label}}
    />
  </template>
}
