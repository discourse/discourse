import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import DModal from "discourse/components/d-modal";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class WatchedWordTesting extends Component {
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

  cleanErrorMessage(message) {
    const parts = message.split(": ");
    return parts[parts.length - 1];
  }

  @cached
  get matchesAndErrors() {
    const errors = {};

    const addError = (word, message) => {
      errors[word] ??= this.cleanErrorMessage(message);
    };

    const errorsToArray = () =>
      Object.entries(errors).map(([word, error]) => ({ word, error }));

    if (!this.value) {
      return { matches: [], errors: [] };
    }

    if (this.isReplace || this.isLink) {
      const matches = [];
      this.args.model.watchedWord.words.forEach((word) => {
        try {
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
        } catch (e) {
          addError(word.word, e.message);
        }
      });
      return { matches, errors: errorsToArray() };
    }

    if (this.isTag) {
      const matches = new Map();
      this.args.model.watchedWord.words.forEach((word) => {
        try {
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
        } catch (e) {
          addError(word.word, e.message);
        }
      });

      return {
        matches: Array.from(matches, ([match, tagsSet]) => ({
          match,
          tags: Array.from(tagsSet),
        })),
        errors: errorsToArray(),
      };
    }

    let matches = [];
    let hasCompiledExpressionError = false;

    this.args.model.watchedWord.compiledRegularExpression.forEach((entry) => {
      try {
        const [regexp, options] = Object.entries(entry)[0];
        const wordRegexp = new RegExp(
          regexp,
          options.case_sensitive ? "gu" : "gui"
        );

        matches.push(...(this.value.match(wordRegexp) || []));
      } catch {
        hasCompiledExpressionError = true;
      }
    });

    if (hasCompiledExpressionError) {
      matches = [];
      this.args.model.watchedWord.words.forEach((word) => {
        try {
          const regexp = new RegExp(
            word.regexp,
            word.case_sensitive ? "gu" : "gui"
          );
          let match;

          while ((match = regexp.exec(this.value)) !== null) {
            matches.push(match[1] || match[0]);
          }
        } catch (e) {
          addError(word.word, e.message);
        }
      });
    }

    return { matches, errors: errorsToArray() };
  }

  get matches() {
    return this.matchesAndErrors.matches;
  }

  get regexErrors() {
    return this.matchesAndErrors.errors;
  }

  <template>
    <DModal
      @title={{i18n
        "admin.watched_words.test.modal_title"
        action=@model.watchedWord.name
      }}
      @closeModal={{@closeModal}}
      class="watched-words-test-modal"
    >
      <:body>
        <p>{{i18n "admin.watched_words.test.description"}}</p>
        <Textarea
          @value={{this.value}}
          name="test_value"
          autofocus="autofocus"
        />

        {{#if this.matches}}
          <p>
            {{i18n "admin.watched_words.test.found_matches"}}
            <ul>
              {{#each this.matches as |match|}}
                <li>
                  {{#if (or this.isReplace this.isLink)}}
                    <span class="match">{{match.match}}</span>
                    &rarr;
                    <span class="replacement">{{match.replacement}}</span>
                  {{else if this.isTag}}
                    <span class="match">{{match.match}}</span>
                    &rarr;
                    {{#each match.tags as |tag|}}
                      <span class="tag">{{tag}}</span>
                    {{/each}}
                  {{else}}
                    {{match}}
                  {{/if}}
                </li>
              {{/each}}
            </ul>
          </p>
        {{else}}
          <p>{{i18n "admin.watched_words.test.no_matches"}}</p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
