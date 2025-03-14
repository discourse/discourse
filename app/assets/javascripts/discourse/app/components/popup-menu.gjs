import Component from "@ember/component";
import { i18n } from "discourse-i18n";

export default class PopupMenu extends Component {
  <template>
    <h3>{{i18n this.title}}</h3>
    <ul>
      {{yield}}
    </ul>
  </template>
}
