import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  isReplace: equal("model.nameKey", "replace"),
  isTag: equal("model.nameKey", "tag"),

  @discourseComputed(
    "value",
    "model.compiledRegularExpression",
    "model.words",
    "isReplace",
    "isTag"
  )
  matches(value, regexpString, words, isReplace, isTag) {
    if (!value || !regexpString) {
      return;
    }

    const regexp = new RegExp(regexpString, "ig");
    const matches = value.match(regexp) || [];

    if (isReplace) {
      return matches.map((match) => ({
        match,
        replacement: words.find((word) =>
          new RegExp(word.regexp, "ig").test(match)
        ).replacement,
      }));
    } else if (isTag) {
      return matches.map((match) => {
        const tags = new Set();

        words.forEach((word) => {
          if (new RegExp(word.regexp, "ig").test(match)) {
            word.replacement.split(",").forEach((tag) => tags.add(tag));
          }
        });

        return { match, tags: Array.from(tags) };
      });
    }

    return matches;
  },
});
