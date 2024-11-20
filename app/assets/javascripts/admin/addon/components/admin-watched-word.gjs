import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AdminWatchedWord extends Component {
  @service dialog;

  get tags() {
    return this.args.word.replacement.split(",");
  }

  @action
  async deleteWord() {
    try {
      await this.args.word.destroy();
      this.args.action(this.args.word);
    } catch (e) {
      this.dialog.alert(
        i18n("generic_error_with_reason", {
          error: `http: ${e.status} - ${e.body}`,
        })
      );
    }
  }

  <template>
    <div class="watched-word">
      <DButton
        @action={{this.deleteWord}}
        @icon="xmark"
        class="btn-transparent delete-word-record"
      />

      <span>{{@word.word}}</span>

      {{#if (or (eq @actionKey "replace") (eq @actionKey "link"))}}
        &rarr;
        <span class="replacement">{{@word.replacement}}</span>
      {{else if (eq @actionKey "tag")}}
        &rarr;
        {{#each this.tags as |tag|}}
          <span class="tag">{{tag}}</span>
        {{/each}}
      {{/if}}

      {{#if @word.case_sensitive}}
        <span class="case-sensitive">
          {{i18n "admin.watched_words.case_sensitive"}}
        </span>
      {{/if}}

      {{#if @word.html}}
        <span class="html">{{i18n "admin.watched_words.html"}}</span>
      {{/if}}
    </div>
  </template>
}
