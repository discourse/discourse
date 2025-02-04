import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("watched-word-input-field")
@selectKitOptions({
  autoInsertNoneItem: false,
  fullWidthOnMobile: true,
  allowAny: true,
  none: "admin.watched_words.form.words_or_phrases",
})
@pluginApiIdentifiers("watched-words")
export default class WatchedWords extends MultiSelectComponent {
  @computed("value.[]")
  get content() {
    return makeArray(this.value).map((x) => this.defaultItem(x, x));
  }
}
