import MultiSelectComponent from "select-kit/components/multi-select";
import { makeArray } from "discourse-common/lib/helpers";
import { computed } from "@ember/object";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["watched-words"],
  classNames: ["watched-word-input-field"],

  selectKitOptions: {
    autoInsertNoneItem: false,
    fullWidthOnMobile: true,
    allowAny: true,
    none: "admin.watched_words.form.words_or_phrases",
  },

  @computed("value.[]")
  get content() {
    return makeArray(this.value).map((x) => this.defaultItem(x, x));
  },
});
