import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import WatchedWord from "discourse/admin/models/watched-word";
import { popupAjaxError } from "discourse/lib/ajax-error";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import WatchedWords from "discourse/select-kit/components/watched-words";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class WatchedWordForm extends Component {
  @service siteSettings;

  @tracked formSubmitted = false;
  @tracked isCaseSensitive = false;
  @tracked isHtml = false;
  @tracked replacement;
  @tracked replacementTags;

  /** @type {{ id?: number | string, name: string }[]} */
  @tracked selectedTags = [];

  /** @type {string[]} */
  @tracked words = [];

  // keyed by action so switching to another action's page hides it
  /** @type {{ text: string, actionKey: string } | null} */
  @tracked shownMessage = null;

  get message() {
    return this.shownMessage?.actionKey === this.args.actionKey
      ? this.shownMessage.text
      : null;
  }

  get submitDisabled() {
    return isEmpty(this.words);
  }

  get canReplace() {
    return this.args.actionKey === "replace";
  }

  get canTag() {
    return this.args.actionKey === "tag";
  }

  get canLink() {
    return this.args.actionKey === "link";
  }

  get placeholderKey() {
    if (this.siteSettings.watched_words_regular_expressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  }

  get isUniqueWord() {
    const existingWords = this.args.filteredContent || [];
    const filtered = existingWords.filter(
      (content) => content.action === this.args.actionKey
    );

    const duplicate = filtered.find((content) => {
      if (content.case_sensitive === true) {
        return this.words?.includes(content.word);
      } else {
        return this.words
          ?.map((w) => w.toLowerCase())
          ?.includes(content.word.toLowerCase());
      }
    });

    return !duplicate;
  }

  @action
  changeWords(words) {
    this.words = words;
    if (!isEmpty(words)) {
      this.shownMessage = null;
    }
  }

  @action
  changeSelectedTags(tags) {
    this.selectedTags = tags;
    this.replacementTags = tags.map((t) =>
      typeof t.id === "number" ? { id: t.id, name: t.name } : { name: t.name }
    );
  }

  @action
  submitForm() {
    if (!this.isUniqueWord) {
      this.shownMessage = {
        text: i18n("admin.watched_words.form.exists"),
        actionKey: this.args.actionKey,
      };
      return;
    }

    if (!this.formSubmitted) {
      this.formSubmitted = true;

      const watchedWord = WatchedWord.create({
        words: this.words,
        replacement: this.canReplace || this.canLink ? this.replacement : null,
        replacementTags: this.canTag ? this.replacementTags : null,
        action: this.args.actionKey,
        isCaseSensitive: this.isCaseSensitive,
        isHtml: this.isHtml,
      });

      watchedWord
        .save()
        .then((result) => {
          this.words = [];
          this.replacement = "";
          this.replacementTags = [];
          this.selectedTags = [];
          this.isCaseSensitive = false;
          this.isHtml = false;
          this.shownMessage = {
            text: i18n("admin.watched_words.form.success"),
            actionKey: this.args.actionKey,
          };
          if (result.words) {
            result.words.forEach((word) => {
              this.args.action(WatchedWord.create(word));
            });
          } else {
            this.args.action(result);
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.formSubmitted = false;
        });
    }
  }

  <template>
    <form class="watched-word-form" ...attributes>
      <div class="watched-word-input">
        <label for="watched-word">{{i18n
            "admin.watched_words.form.label"
          }}</label>
        <WatchedWords
          @id="watched-words"
          @onChange={{this.changeWords}}
          @options={{hash
            filterPlaceholder=this.placeholderKey
            disabled=this.formSubmitted
          }}
          @value={{this.words}}
        />
      </div>

      {{#if this.canReplace}}
        <div class="watched-word-input">
          <label for="watched-replacement">{{i18n
              "admin.watched_words.form.replace_label"
            }}</label>
          <DTextField
            class="watched-word-input-field"
            @autocapitalize="off"
            @autocorrect="off"
            @disabled={{this.formSubmitted}}
            @id="watched-replacement"
            @placeholderKey="admin.watched_words.form.replace_placeholder"
            @value={{this.replacement}}
          />
        </div>
      {{/if}}

      {{#if this.canTag}}
        <div class="watched-word-input">
          <label for="watched-tag">{{i18n
              "admin.watched_words.form.tag_label"
            }}</label>
          <TagChooser
            class="watched-word-input-field"
            @everyTag={{true}}
            @id="watched-tag"
            @onChange={{this.changeSelectedTags}}
            @options={{hash allowAny=true disabled=this.formSubmitted}}
            @tags={{this.selectedTags}}
          />
        </div>
      {{/if}}

      {{#if this.canLink}}
        <div class="watched-word-input">
          <label for="watched-link">{{i18n
              "admin.watched_words.form.link_label"
            }}</label>
          <DTextField
            class="watched-word-input-field"
            @autocapitalize="off"
            @autocorrect="off"
            @disabled={{this.formSubmitted}}
            @id="watched-link"
            @placeholderKey="admin.watched_words.form.link_placeholder"
            @value={{this.replacement}}
          />
        </div>
      {{/if}}

      <div class="watched-word-input">
        <label for="watched-case-sensitivity">{{i18n
            "admin.watched_words.form.case_sensitivity_label"
          }}</label>
        <label class="case-sensitivity-checkbox checkbox-label">
          <Input
            disabled={{this.formSubmitted}}
            @checked={{this.isCaseSensitive}}
            @type="checkbox"
          />
          {{i18n "admin.watched_words.form.case_sensitivity_description"}}
        </label>
      </div>

      {{#if this.canReplace}}
        <div class="watched-word-input">
          <label for="watched-html">{{i18n
              "admin.watched_words.form.html_label"
            }}</label>
          <label class="html-checkbox checkbox-label">
            <Input
              disabled={{this.formSubmitted}}
              @checked={{this.isHtml}}
              @type="checkbox"
            />
            {{i18n "admin.watched_words.form.html_description"}}
          </label>
        </div>
      {{/if}}

      <DButton
        class="btn-primary"
        type="submit"
        @action={{this.submitForm}}
        @disabled={{this.submitDisabled}}
        @label="admin.watched_words.form.add"
      />

      {{#if this.message}}
        <span class="success-message">{{this.message}}</span>
      {{/if}}
    </form>
  </template>
}
