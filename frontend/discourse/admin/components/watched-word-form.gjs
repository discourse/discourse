/* eslint-disable ember/no-classic-components, ember/no-observers */
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import WatchedWord from "discourse/admin/models/watched-word";
import { popupAjaxError } from "discourse/lib/ajax-error";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import WatchedWords from "discourse/select-kit/components/watched-words";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

@tagName("")
export default class WatchedWordForm extends Component {
  formSubmitted = false;
  actionKey = null;
  showMessage = false;
  isCaseSensitive = false;
  isHtml = false;
  selectedTags = [];
  words = [];

  @computed("words.length")
  get submitDisabled() {
    return isEmpty(this.words);
  }

  @computed("actionKey")
  get canReplace() {
    return this.actionKey === "replace";
  }

  @computed("actionKey")
  get canTag() {
    return this.actionKey === "tag";
  }

  @computed("actionKey")
  get canLink() {
    return this.actionKey === "link";
  }

  @computed("siteSettings.watched_words_regular_expressions")
  get placeholderKey() {
    if (this.siteSettings?.watched_words_regular_expressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  }

  @computed("words.[]")
  get isUniqueWord() {
    const existingWords = this.filteredContent || [];
    const filtered = existingWords.filter(
      (content) => content.action === this.actionKey
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

  @action
  changeSelectedTags(tags) {
    this.setProperties({
      selectedTags: tags,
      replacementTags: tags.map((t) =>
        typeof t.id === "number" ? { id: t.id, name: t.name } : { name: t.name }
      ),
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
        replacement: this.canReplace || this.canLink ? this.replacement : null,
        replacementTags: this.canTag ? this.replacementTags : null,
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
            replacementTags: [],
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
    <form class="watched-word-form" ...attributes>
      <div class="watched-word-input">
        <label for="watched-word">{{i18n
            "admin.watched_words.form.label"
          }}</label>
        <WatchedWords
          @id="watched-words"
          @onChange={{fn (mut this.words)}}
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

      {{#if this.showMessage}}
        <span class="success-message">{{this.message}}</span>
      {{/if}}
    </form>
  </template>
}
