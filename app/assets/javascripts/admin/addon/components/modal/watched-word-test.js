import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class WatchedWordTest extends Component {
  @tracked value;

  get isReplace() {
    return this.args.model.watchedWord.nameKey === "replace";
  }

  get isTag() {
    return this.args.model.watchedWord.nameKey === "tag";
  }

  get isLink() {
    return this.args.model.watchedWord.nameKey === "link";
  }

  get matches() {
    if (
      !this.value ||
      this.args.model.watchedWord.compiledRegularExpression.length === 0
    ) {
      return [];
    }

    if (this.isReplace || this.isLink) {
      const matches = [];
      this.args.model.watchedWord.words.forEach((word) => {
        const caseFlag = word.case_sensitive ? "" : "i";
        const regexp = new RegExp(word.regexp, `${caseFlag}gu`);
        let match;

        while ((match = regexp.exec(this.value)) !== null) {
          matches.push({
            match: match[1],
            replacement: word.replacement,
          });
        }
      });
      return matches;
    } else if (this.isTag) {
      const matches = {};
      this.args.model.watchedWord.words.forEach((word) => {
        const caseFlag = word.case_sensitive ? "" : "i";
        const regexp = new RegExp(word.regexp, `${caseFlag}gu`);
        let match;

        while ((match = regexp.exec(this.value)) !== null) {
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
      this.args.model.watchedWord.compiledRegularExpression.forEach((entry) => {
        const [regexp, options] = Object.entries(entry)[0];
        const caseFlag = options.case_sensitive ? "" : "i";
        const wordRegexp = new RegExp(regexp, `${caseFlag}gu`);

        matches.push(...(this.value.match(wordRegexp) || []));
      });

      return matches;
    }
  }
}
