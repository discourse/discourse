import { Input } from "@ember/component";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import basePath from "discourse/helpers/base-path";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import AdminWatchedWord from "admin/components/admin-watched-word";
import WatchedWordForm from "admin/components/watched-word-form";
import WatchedWordUploader from "admin/components/watched-word-uploader";

export default RouteTemplate(
  <template>
    {{#if @controller.regexpError}}
      <div class="alert alert-error">{{@controller.regexpError}}</div>
    {{/if}}

    <div class="watched-word-controls">
      <DButton
        @href={{@controller.downloadLink}}
        @icon="download"
        @label="admin.watched_words.download"
        class="btn-default download-link"
      />

      <WatchedWordUploader
        @uploading={{@controller.uploading}}
        @actionKey={{@controller.actionNameKey}}
        @done={{@controller.uploadComplete}}
      />

      <DButton
        @label="admin.watched_words.test.button_label"
        @icon="far-eye"
        @action={{@controller.test}}
        class="btn-default watched-word-test"
      />

      <DButton
        @label="admin.watched_words.clear_all"
        @icon="trash-can"
        @action={{@controller.clearAll}}
        class="btn-danger clear-all"
      />
    </div>

    <p class="about">{{@controller.actionDescription}}</p>

    {{#if @controller.siteSettings.watched_words_regular_expressions}}
      <p>
        {{htmlSafe
          (i18n "admin.watched_words.regex_warning" basePath=(basePath))
        }}
      </p>
    {{/if}}

    <WatchedWordForm
      @actionKey={{@controller.actionNameKey}}
      @action={{@controller.recordAdded}}
      @filteredContent={{@controller.currentAction.words}}
    />

    {{#if @controller.currentAction.words}}
      <label class="show-words-checkbox">
        <Input
          @type="checkbox"
          @checked={{@controller.adminWatchedWords.showWords}}
          disabled={{@controller.adminWatchedWords.disableShowWords}}
        />
        {{i18n
          "admin.watched_words.show_words"
          count=@controller.currentAction.words.length
        }}
      </label>
    {{/if}}

    {{#if @controller.showWordsList}}
      <div
        class="watched-words-list watched-words-{{@controller.actionNameKey}}"
      >
        {{#each @controller.currentAction.words as |word|}}
          <div class="watched-word-box">
            <AdminWatchedWord
              @actionKey={{@controller.actionNameKey}}
              @word={{word}}
              @action={{@controller.recordRemoved}}
            />
          </div>
        {{/each}}
      </div>
    {{/if}}
  </template>
);
