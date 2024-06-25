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
        const regexp = new RegExp(
          word.regexp,
          word.case_sensitive ? "gu" : "gui"
        );
        let match;

        while ((match = regexp.exec(this.value)) !== null) {
          matches.push({
            match: match[1],
            replacement: word.replacement,
          });
        }
      });
      return matches;
    }

    if (this.isTag) {
      const matches = new Map();
      this.args.model.watchedWord.words.forEach((word) => {
        const regexp = new RegExp(
          word.regexp,
          word.case_sensitive ? "gu" : "gui"
        );
        let match;

        while ((match = regexp.exec(this.value)) !== null) {
          if (!matches.has(match[1])) {
            matches.set(match[1], new Set());
          }

          const tags = matches.get(match[1]);
          word.replacement.split(",").forEach((tag) => tags.add(tag));
        }
      });

      return Array.from(matches, ([match, tagsSet]) => ({
        match,
        tags: Array.from(tagsSet),
      }));
    }

    let matches = [];
    this.args.model.watchedWord.compiledRegularExpression.forEach((entry) => {
      const [regexp, options] = Object.entries(entry)[0];
      const wordRegexp = new RegExp(
        regexp,
        options.case_sensitive ? "gu" : "gui"
      );

      matches.push(...(this.value.match(wordRegexp) || []));
    });

    return matches;
  }
}
