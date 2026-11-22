import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import type User from "discourse/models/user";
import { i18n } from "discourse-i18n";

interface DCountI18nSignature {
  Args: {
    /** The translation key. Its translation receives `@count`, and its markup is rendered. */
    key: string;

    /** Appended to `@key`, for keys that end in a filter name, such as `topic_count_`. */
    suffix?: string;

    /** The number the translation is pluralized by. */
    count?: number;
  };
}

export default class DCountI18n extends Component<DCountI18nSignature> {
  @service declare currentUser: User | null;

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
