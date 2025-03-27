import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { empty, equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { classNames, tagName } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import WatchedWord from "admin/models/watched-word";
import TagChooser from "select-kit/components/tag-chooser";
import WatchedWords from "select-kit/components/watched-words";

@tagName("form")
@classNames("watched-word-form")
export default class WatchedWordForm extends Component {
  @service dialog;

  formSubmitted = false;
  actionKey = null;
  showMessage = false;
  isCaseSensitive = false;
  isHtml = false;
  selectedTags = [];
  words = [];

  @empty("words") submitDisabled;
  @equal("actionKey", "replace") canReplace;
  @equal("actionKey", "tag") canTag;
  @equal("actionKey", "link") canLink;

  @discourseComputed("siteSettings.watched_words_regular_expressions")
  placeholderKey(watchedWordsRegularExpressions) {
    if (watchedWordsRegularExpressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  }

  @observes("words.[]")
  removeMessage() {
    if (this.showMessage && !isEmpty(this.words)) {
      this.set("showMessage", false);
    }
  }

  @observes("actionKey")
  actionChanged() {
    this.setProperties({
      showMessage: false,
    });
  }

  @discourseComputed("words.[]")
  isUniqueWord(words) {
    const existingWords = this.filteredContent || [];
    const filtered = existingWords.filter(
      (content) => content.action === this.actionKey
    );

    const duplicate = filtered.find((content) => {
      if (content.case_sensitive === true) {
        return words.includes(content.word);
      } else {
        return words
          .map((w) => w.toLowerCase())
          .includes(content.word.toLowerCase());
      }
    });

    return !duplicate;
  }

  @action
  changeSelectedTags(tags) {
    this.setProperties({
      selectedTags: tags,
      replacement: tags.join(","),
    });
  }

  @action
  submitForm() {
    if (!this.isUniqueWord) {
      this.setProperties({
        showMessage: true,
        message: i18n("admin.watched_words.form.exists"),
      });
      return;
    }

    if (!this.formSubmitted) {
      this.set("formSubmitted", true);

      const watchedWord = WatchedWord.create({
        words: this.words,
        replacement:
          this.canReplace || this.canTag || this.canLink
            ? this.replacement
            : null,
        action: this.actionKey,
        isCaseSensitive: this.isCaseSensitive,
        isHtml: this.isHtml,
      });

      watchedWord
        .save()
        .then((result) => {
          this.setProperties({
            words: [],
            replacement: "",
            selectedTags: [],
            showMessage: true,
            message: i18n("admin.watched_words.form.success"),
            isCaseSensitive: false,
            isHtml: false,
          });
          if (result.words) {
            result.words.forEach((word) => {
              this.action(WatchedWord.create(word));
            });
          } else {
            this.action(result);
          }
        })
        .catch(popupAjaxError)
        .finally(this.set("formSubmitted", false));
    }
  }

  <template>
    <div class="watched-word-input">
      <label for="watched-word">{{i18n
          "admin.watched_words.form.label"
        }}</label>
      <WatchedWords
        @id="watched-words"
        @value={{this.words}}
        @onChange={{fn (mut this.words)}}
        @options={{hash
          filterPlaceholder=this.placeholderKey
          disabled=this.formSubmitted
        }}
      />
    </div>

    {{#if this.canReplace}}
      <div class="watched-word-input">
        <label for="watched-replacement">{{i18n
            "admin.watched_words.form.replace_label"
          }}</label>
        <TextField
          @id="watched-replacement"
          @value={{this.replacement}}
          @disabled={{this.formSubmitted}}
          @autocorrect="off"
          @autocapitalize="off"
          @placeholderKey="admin.watched_words.form.replace_placeholder"
          class="watched-word-input-field"
        />
      </div>
    {{/if}}

    {{#if this.canTag}}
      <div class="watched-word-input">
        <label for="watched-tag">{{i18n
            "admin.watched_words.form.tag_label"
          }}</label>
        <TagChooser
          @id="watched-tag"
          @tags={{this.selectedTags}}
          @onChange={{this.changeSelectedTags}}
          @everyTag={{true}}
          @options={{hash allowAny=true disabled=this.formSubmitted}}
          class="watched-word-input-field"
        />
      </div>
    {{/if}}

    {{#if this.canLink}}
      <div class="watched-word-input">
        <label for="watched-link">{{i18n
            "admin.watched_words.form.link_label"
          }}</label>
        <TextField
          @id="watched-link"
          @value={{this.replacement}}
          @disabled={{this.formSubmitted}}
          @autocorrect="off"
          @autocapitalize="off"
          @placeholderKey="admin.watched_words.form.link_placeholder"
          class="watched-word-input-field"
        />
      </div>
    {{/if}}

    <div class="watched-word-input">
      <label for="watched-case-sensitivity">{{i18n
          "admin.watched_words.form.case_sensitivity_label"
        }}</label>
      <label class="case-sensitivity-checkbox checkbox-label">
        <Input
          @type="checkbox"
          @checked={{this.isCaseSensitive}}
          disabled={{this.formSubmitted}}
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
            @type="checkbox"
            @checked={{this.isHtml}}
            disabled={{this.formSubmitted}}
          />
          {{i18n "admin.watched_words.form.html_description"}}
        </label>
      </div>
    {{/if}}

    <DButton
      @action={{this.submitForm}}
      @disabled={{this.submitDisabled}}
      @label="admin.watched_words.form.add"
      type="submit"
      class="btn-primary"
    />

    {{#if this.showMessage}}
      <span class="success-message">{{this.message}}</span>
    {{/if}}
  </template>
}
