import Modal from "discourse/controllers/modal";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import {
  createWatchedWordRegExp,
  toWatchedWord,
} from "discourse-common/utils/watched-words";

export default Modal.extend({
  isReplace: equal("model.nameKey", "replace"),
  isTag: equal("model.nameKey", "tag"),
  isLink: equal("model.nameKey", "link"),

  @discourseComputed(
    "value",
    "model.compiledRegularExpression",
    "model.words",
    "isReplace",
    "isTag",
    "isLink"
  )
  matches(value, regexpList, words, isReplace, isTag, isLink) {
    if (!value || regexpList.length === 0) {
      return [];
    }

    if (isReplace || isLink) {
      const matches = [];
      words.forEach((word) => {
        const regexp = createWatchedWordRegExp(word);
        let match;

        while ((match = regexp.exec(value)) !== null) {
          matches.push({
            match: match[1],
            replacement: word.replacement,
          });
        }
      });
      return matches;
    } else if (isTag) {
      const matches = {};
      words.forEach((word) => {
        const regexp = createWatchedWordRegExp(word);
        let match;

        while ((match = regexp.exec(value)) !== null) {
          if (!matches[match[1]]) {
            matches[match[1]] = new Set();
          }

          let tags = matches[match[1]];
          word.replacement.split(",").forEach((tag) => {
            tags.add(tag);
          });
        }
      });

      return Object.entries(matches).map((entry) => ({
        match: entry[0],
        tags: Array.from(entry[1]),
      }));
    } else {
      let matches = [];
      regexpList.forEach((regexp) => {
        const wordRegexp = createWatchedWordRegExp(toWatchedWord(regexp));

        matches.push(...(value.match(wordRegexp) || []));
      });

      return matches;
    }
  },
});
