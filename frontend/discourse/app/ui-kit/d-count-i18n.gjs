import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";

export default class DCountI18n extends Component {
  @service(() => CurrentUserService) currentUser;

  get fullKey() {
    let key = this.args.key;

    if (this.args.suffix) {
      key += this.args.suffix;
    }

    if (this.currentUser?.unified_new_enabled && key === "topic_count_new") {
      key = "topic_count_latest";
    }

    return key;
  }

  <template>
    <span>{{trustHTML (i18n this.fullKey count=@count)}}</span>
  </template>
}
