import { Input } from "@ember/component";
import { trustHTML } from "@ember/template";
import AdminWatchedWord from "discourse/admin/components/admin-watched-word";
import WatchedWordForm from "discourse/admin/components/watched-word-form";
import WatchedWordUploader from "discourse/admin/components/watched-word-uploader";
import DButton from "discourse/ui-kit/d-button";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.regexpErrors.length}}
    <div class="alert alert-error">
      <strong>{{i18n "admin.watched_words.invalid_regex_multiple"}}</strong>
      <ul class="watched-word-regex-errors">
        {{#each @controller.regexpErrors as |error|}}
          <li>
            <strong>{{error.word}}</strong>:
            {{error.error}}
          </li>
        {{/each}}
      </ul>
    </div>
  {{/if}}

  <div class="watched-word-controls">
    <DButton
      class="btn-default download-link"
      @action={{@controller.downloadAction}}
      @href={{@controller.downloadLink}}
      @icon="download"
      @label="admin.watched_words.download"
    />

    <WatchedWordUploader
      @actionKey={{@controller.actionNameKey}}
      @done={{@controller.uploadComplete}}
      @uploading={{@controller.uploading}}
    />

    <DButton
      class="btn-default watched-word-test"
      @action={{@controller.test}}
      @icon="far-eye"
      @label="admin.watched_words.test.button_label"
    />

    <DButton
      class="btn-danger clear-all"
      @action={{@controller.clearAll}}
      @icon="trash-can"
      @label="admin.watched_words.clear_all"
    />
  </div>

  <p class="about">{{@controller.actionDescription}}</p>

  {{#if @controller.siteSettings.watched_words_regular_expressions}}
    <p>
      {{trustHTML
        (i18n "admin.watched_words.regex_warning" basePath=(dBasePath))
      }}
    </p>
  {{/if}}

  <WatchedWordForm
    @action={{@controller.recordAdded}}
    @actionKey={{@controller.actionNameKey}}
    @filteredContent={{@controller.currentActionFiltered.words}}
  />

  {{#if @controller.currentActionFiltered.words}}
    <label class="show-words-checkbox">
      <Input
        disabled={{@controller.adminWatchedWords.disableShowWords}}
        @checked={{@controller.adminWatchedWords.showWords}}
        @type="checkbox"
      />
      {{i18n
        "admin.watched_words.show_words"
        count=@controller.currentActionFiltered.words.length
      }}
    </label>
  {{/if}}

  {{#if @controller.showWordsList}}
    <div class="watched-words-list watched-words-{{@controller.actionNameKey}}">
      {{#each @controller.currentActionFiltered.words as |word|}}
        <div class="watched-word-box">
          <AdminWatchedWord
            @action={{@controller.recordRemoved}}
            @actionKey={{@controller.actionNameKey}}
            @word={{word}}
          />
        </div>
      {{/each}}
    </div>
  {{/if}}
</template>
