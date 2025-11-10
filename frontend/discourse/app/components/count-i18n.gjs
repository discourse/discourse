import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class CountI18n extends Component {
  @service currentUser;

  get fullKey() {
    let key = this.args.key;

    if (this.args.suffix) {
      key += this.args.suffix;
    }

    if (this.currentUser?.new_new_view_enabled && key === "topic_count_new") {
      key = "topic_count_latest";
    }

    return key;
  }

  <template>
    <span>{{htmlSafe (i18n this.fullKey count=@count)}}</span>
  </template>
}
