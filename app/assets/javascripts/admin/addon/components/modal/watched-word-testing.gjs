import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { or } from "truth-helpers";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";

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
