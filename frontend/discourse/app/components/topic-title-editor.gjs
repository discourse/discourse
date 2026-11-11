import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import lazyHash from "discourse/helpers/lazy-hash";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PluginOutlet from "./plugin-outlet.gjs";

export default class TopicTitleEditor extends Component {
  @service languageNameLookup;
  @service siteSettings;

  focusAtEnd = modifier((element) => {
    element.focus({ preventScroll: true });
    element.setSelectionRange(element.value.length, element.value.length);
  });

  get translationLocaleName() {
    return this.languageNameLookup.getLanguageName(this.args.translationLocale);
  }

  get title() {
    return this.args.isEditingLocalization
      ? this.args.translationTitle
      : this.args.bufferedTitle;
  }

  get dir() {
    return this.siteSettings.support_mixed_text_direction ? "auto" : null;
  }

  // the textarea only exists so long titles can wrap; a title is still one line
  @action
  preventNewline(event) {
    if (event.key === "Enter" && !event.isComposing) {
      event.preventDefault();
    }
  }

  @action
  updateTitle(event) {
    const textarea = event.target;
    const { selectionStart, selectionEnd, selectionDirection } = textarea;
    let start = selectionStart;
    let end = selectionEnd;
    const title = textarea.value.replace(/\s*\n\s*/g, (match, offset) => {
      if (selectionStart > offset) {
        start -= Math.min(selectionStart - offset, match.length) - 1;
      }
      if (selectionEnd > offset) {
        end -= Math.min(selectionEnd - offset, match.length) - 1;
      }
      return " ";
    });

    if (title !== textarea.value) {
      textarea.value = title;
      textarea.setSelectionRange(start, end, selectionDirection);
    }

    if (this.args.isEditingLocalization) {
      this.args.onTranslationTitleChange(title);
    } else {
      this.args.buffered.set("title", title);
    }
  }

  <template>
    {{#if @isEditingLocalization}}
      <div class="editing-localization-indicator">
        {{dIcon "language"}}
        {{i18n
          "topic.localizations.editing_translation"
          language=this.translationLocaleName
        }}
      </div>
    {{/if}}
    <div class="edit-title__wrapper">
      <PluginOutlet
        @name="edit-topic-title"
        @outletArgs={{lazyHash model=@model buffered=@buffered}}
      >
        <DExpandingTextArea
          dir={{this.dir}}
          id="edit-title"
          @input={{this.updateTitle}}
          @maxlength={{this.siteSettings.max_topic_title_length}}
          @rows="1"
          @value={{this.title}}
          {{on "keydown" this.preventNewline}}
          {{this.focusAtEnd}}
        />
      </PluginOutlet>
    </div>
  </template>
}
