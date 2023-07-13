import { equal } from "@ember/object/computed";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import {
  createWatchedWordRegExp,
  toWatchedWord,
} from "discourse-common/utils/watched-words";

export default class AdminWatchedWordTestController extends Controller.extend(
  ModalFunctionality
) {
  @equal("model.nameKey", "replace") isReplace;

  @equal("model.nameKey", "tag") isTag;
  @equal("model.nameKey", "link") isLink;

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
  }
}
