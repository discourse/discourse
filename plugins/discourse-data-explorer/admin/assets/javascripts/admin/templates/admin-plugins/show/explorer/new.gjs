import { on } from "@ember/modifier";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import DSegmentedControl from "discourse/components/d-segmented-control";
import Form from "discourse/components/form";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DTextField from "discourse/ui-kit/d-text-field";
import DTextarea from "discourse/ui-kit/d-textarea";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ExplorerSchema from "discourse/plugins/discourse-data-explorer/discourse/components/explorer-schema";
import QueryModeSwitch from "discourse/plugins/discourse-data-explorer/discourse/components/query-mode-switch";
import QueryResult from "discourse/plugins/discourse-data-explorer/discourse/components/query-result";

export default <template>
  <div class="admin-detail">
    <div class="query-new__top-bar">
      <BackButton
        @label="explorer.queries"
        @route="adminPlugins.show.explorer.index"
      />

      {{#if @controller.aiQueriesEnabled}}
        <QueryModeSwitch
          @onChange={{@controller.setMode}}
          @value={{@controller.mode}}
        />
      {{/if}}
    </div>

    <div class="query-new">
      {{#if (and @controller.aiQueriesEnabled (eq @controller.mode "ai"))}}
        <div class="query-new__ai-section">
          <label class="query-new__ai-label">
            <span>{{i18n "explorer.ai.description_title"}}</span>
            {{dIcon "discourse-sparkles"}}
          </label>

          <p class="query-new__ai-hint">
            {{i18n "explorer.ai.description_hint"}}
          </p>

          <DTextarea
            class="query-new__ai-textarea"
            disabled={{@controller.aiGenerating}}
            placeholder={{i18n "explorer.ai.description_placeholder"}}
            @value={{@controller.aiDescription}}
            {{on "input" @controller.updateAiDescription}}
            {{on "keydown" @controller.handleKeydown}}
          />

          <div class="query-new__ai-actions">
            {{#if @controller.hasGenerated}}
              <DButton
                class="btn-default query-new__regenerate-btn"
                @action={{@controller.generate}}
                @disabled={{@controller.aiGenerating}}
                @icon="discourse-sparkles"
                @label="explorer.ai.regenerate"
              />
            {{else}}
              <DButton
                class="btn-primary query-new__generate-btn"
                @action={{@controller.generate}}
                @disabled={{@controller.aiGenerating}}
                @label="explorer.ai.generate"
              />
            {{/if}}

            {{#if @controller.aiGenerating}}
              <span class="query-new__generating-indicator">
                <DConditionalLoadingSpinner @condition={{true}} @size="small" />
                <span>{{i18n "explorer.ai.generating"}}</span>
              </span>
            {{/if}}
          </div>
        </div>

        {{#if @controller.hasGenerated}}
          <hr class="query-new__divider" />

          <div class="query-new__result-bar">
            {{#if @controller.previewSucceeded}}
              <div class="query-new__result-about">
                {{@controller.previewResultCount}}
                {{@controller.previewDuration}}
              </div>
            {{/if}}

            <DSegmentedControl
              class="query-results-modes"
              @items={{@controller.viewItems}}
              @name="query-result-view"
              @onSelect={{@controller.setView}}
              @translatedLabel={{i18n "explorer.view.label"}}
              @value={{@controller.view}}
            />
          </div>

          {{#if (eq @controller.view "sql")}}
            <div class="query-new__sql-editor">
              <AceEditor
                @content={{@controller.generatedSql}}
                @mode="sql"
                @onChange={{@controller.updateSql}}
                @resizable={{true}}
              />
            </div>
          {{else}}
            <div class="query-new__preview query-results">
              {{#if @controller.previewLoading}}
                <DConditionalLoadingSpinner @condition={{true}} />
              {{else if @controller.previewSucceeded}}
                <QueryResult
                  @content={{@controller.previewResults}}
                  @hideHeaderActions={{true}}
                  @onSetView={{@controller.setView}}
                  @showDownloads={{false}}
                  @view={{@controller.view}}
                />
              {{else if @controller.showPreview}}
                {{#each @controller.previewResults.errors as |err|}}
                  <pre class="query-error"><code>{{~err}}</code></pre>
                {{/each}}
              {{/if}}
            </div>
          {{/if}}

          <div class="query-new__fields">
            <label class="query-new__field-label">
              {{i18n "explorer.query_name"}}
            </label>
            <DTextField
              class="query-new__name-input"
              @onChange={{@controller.updateName}}
              @value={{@controller.generatedName}}
            />

            <label class="query-new__field-label">
              {{i18n "explorer.description_placeholder"}}
              <span class="query-new__optional">
                ({{i18n "explorer.ai.optional"}})
              </span>
            </label>
            <DTextarea
              class="query-new__description-input"
              @value={{@controller.generatedDescription}}
              {{on "input" @controller.updateDescription}}
            />

            <label class="query-new__field-label">
              {{i18n "explorer.allow_groups"}}
            </label>
            <GroupChooser
              class="query-group-select"
              @content={{@controller.groupOptions}}
              @onChange={{@controller.updateAiGroupIds}}
              @value={{@controller.aiGroupIds}}
            />
          </div>

          <div class="query-new__actions">
            <DButton
              class="btn-default query-new__run-btn"
              @action={{@controller.runPreview}}
              @disabled={{@controller.previewDisabled}}
              @icon="play"
              @label="explorer.run"
            />
            <DButton
              class="btn-primary query-new__save-btn"
              @action={{@controller.saveQuery}}
              @disabled={{@controller.aiGenerating}}
              @label="explorer.ai.save_query"
            />
          </div>
        {{/if}}
      {{else}}
        <Form
          class="query-new__manual-form"
          @data={{@controller.manualFormData}}
          @onSubmit={{@controller.create}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="name"
            @title={{i18n "explorer.query_name"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Field
            @format="full"
            @name="description"
            @title={{i18n "explorer.description_placeholder"}}
            @type="textarea"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Field
            @format="full"
            @name="groupIds"
            @title={{i18n "explorer.allow_groups"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <GroupChooser
                class="query-group-select"
                @content={{@controller.groupOptions}}
                @onChange={{field.set}}
                @value={{field.value}}
              />
            </field.Control>
          </form.Field>
          <label class="query-new__sql-label">
            {{i18n "explorer.ai.sql_label"}}
          </label>
          <div class="query-editor {{if @controller.hideSchema 'no-schema'}}">
            <div class="panels-flex">
              <div class="editor-panel">
                <AceEditor
                  @content={{@controller.manualSql}}
                  @mode="sql"
                  @onChange={{@controller.updateManualSql}}
                />
              </div>
              <div class="right-panel">
                <ExplorerSchema
                  @hideSchema={{@controller.hideSchema}}
                  @schema={{@controller.schema}}
                  @updateHideSchema={{@controller.updateHideSchema}}
                />
              </div>
            </div>
            <div class="clear"></div>
          </div>
          <form.Actions>
            <form.Submit @icon="plus" @label="explorer.create" />
          </form.Actions>
        </Form>
      {{/if}}
    </div>
  </div>
</template>
