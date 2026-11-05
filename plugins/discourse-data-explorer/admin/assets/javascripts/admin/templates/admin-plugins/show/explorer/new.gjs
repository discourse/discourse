import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import DSegmentedControl from "discourse/components/d-segmented-control";
import Form from "discourse/components/form";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ExplorerSchema from "discourse/plugins/discourse-data-explorer/discourse/components/explorer-schema";
import QueryModeSwitch from "discourse/plugins/discourse-data-explorer/discourse/components/query-mode-switch";
import QueryResult from "discourse/plugins/discourse-data-explorer/discourse/components/query-result";
import QueryTagChooser from "discourse/plugins/discourse-data-explorer/discourse/components/query-tag-chooser";

export default <template>
  <div class="admin-detail">
    <div class="query-new__top-bar">
      <BackButton
        @label="explorer.back_to_queries"
        @route="adminPlugins.show.explorer.index"
      />

      {{#if @controller.aiQueriesEnabled}}
        <QueryModeSwitch
          @onChange={{@controller.setMode}}
          @value={{@controller.mode}}
        />
      {{/if}}
    </div>

    {{! the header block only renders in AI mode, when @heading is unset }}
    <AdminConfigAreaCard
      @heading={{unless @controller.isAiMode "explorer.new_query"}}
    >
      <:header>
        <span class="query-new__ai-heading" id="query-new-ai-heading">
          {{i18n "explorer.ai.description_title"}}
          {{dIcon "discourse-sparkles"}}
        </span>
      </:header>
      <:content>
        <div class="query-new">
          {{#if @controller.isAiMode}}
            <div class="query-new__ai-section">
              <Form
                class="query-new__ai-form"
                @data={{@controller.aiPromptData}}
                @onRegisterApi={{@controller.registerAiPromptApi}}
                @onSubmit={{@controller.generate}}
                as |form|
              >
                <form.Field
                  @description={{i18n "explorer.ai.description_hint"}}
                  @disabled={{@controller.aiGenerating}}
                  @format="full"
                  @name="prompt"
                  @showTitle={{false}}
                  @title={{i18n "explorer.ai.description_title"}}
                  @type="textarea"
                  @validation="required"
                  as |field|
                >
                  <field.Control
                    aria-labelledby="query-new-ai-heading"
                    placeholder={{i18n "explorer.ai.description_placeholder"}}
                  />
                </form.Field>
                <form.Actions>
                  {{#if @controller.hasGenerated}}
                    <form.Button
                      class="btn-default query-new__regenerate-btn"
                      @action={{@controller.submitAiPrompt}}
                      @disabled={{@controller.aiGenerating}}
                      @icon="discourse-sparkles"
                      @label="explorer.ai.regenerate"
                    />
                  {{else}}
                    <form.Submit
                      class="query-new__generate-btn"
                      @disabled={{@controller.aiGenerating}}
                      @label="explorer.ai.generate"
                    />
                  {{/if}}

                  {{#if @controller.aiGenerating}}
                    <span class="query-new__generating-indicator">
                      <DConditionalLoadingSpinner
                        @condition={{true}}
                        @size="small"
                      />
                      <span>{{i18n "explorer.ai.generating"}}</span>
                    </span>
                  {{/if}}
                </form.Actions>
              </Form>
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

              <Form
                class="query-new__fields"
                @data={{@controller.aiFormData}}
                @onRegisterApi={{@controller.registerAiFormApi}}
                @onSubmit={{@controller.saveQuery}}
                as |form|
              >
                <form.Field
                  @format="full"
                  @name="name"
                  @title={{i18n "explorer.name"}}
                  @type="input"
                  @validation="required"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Field
                  @format="full"
                  @name="description"
                  @title={{i18n "explorer.query_description"}}
                  @type="textarea"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Row as |row|>
                  <row.Col @size={{6}}>
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
                  </row.Col>
                  <row.Col @size={{6}}>
                    <form.Field
                      @format="full"
                      @name="tags"
                      @title={{i18n "explorer.query_tags"}}
                      @type="custom"
                      as |field|
                    >
                      <field.Control>
                        <QueryTagChooser
                          @availableTags={{@controller.availableTags}}
                          @onChange={{field.set}}
                          @value={{field.value}}
                        />
                      </field.Control>
                    </form.Field>
                  </row.Col>
                </form.Row>
                <form.Actions>
                  <form.Button
                    class="btn-default query-new__run-btn"
                    @action={{@controller.runPreview}}
                    @disabled={{@controller.previewDisabled}}
                    @icon="play"
                    @label="explorer.run"
                  />
                  <form.Submit
                    class="query-new__save-btn"
                    @disabled={{@controller.aiGenerating}}
                    @label="explorer.ai.save_query"
                  />
                </form.Actions>
              </Form>
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
                @title={{i18n "explorer.name"}}
                @type="input"
                @validation="required"
                as |field|
              >
                <field.Control />
              </form.Field>
              <form.Field
                @format="full"
                @name="description"
                @title={{i18n "explorer.query_description"}}
                @type="textarea"
                as |field|
              >
                <field.Control />
              </form.Field>
              <form.Row as |row|>
                <row.Col @size={{6}}>
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
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @format="full"
                    @name="tags"
                    @title={{i18n "explorer.query_tags"}}
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <QueryTagChooser
                        @availableTags={{@controller.availableTags}}
                        @onChange={{field.set}}
                        @value={{field.value}}
                      />
                    </field.Control>
                  </form.Field>
                </row.Col>
              </form.Row>
              <label class="query-new__sql-label">
                {{i18n "explorer.ai.sql_label"}}
              </label>
              <div
                class="query-editor {{if @controller.hideSchema 'no-schema'}}"
              >
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
              </div>
              <form.Actions>
                <form.Submit @icon="plus" @label="explorer.create" />
              </form.Actions>
            </Form>
          {{/if}}
        </div>
      </:content>
    </AdminConfigAreaCard>
  </div>
</template>
