import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import DSegmentedControl from "discourse/components/d-segmented-control";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, eq, notEq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import DTextField from "discourse/ui-kit/d-text-field";
import DTextarea from "discourse/ui-kit/d-textarea";
import { i18n } from "discourse-i18n";
import CodeView from "discourse/plugins/discourse-data-explorer/discourse/components/code-view";
import ExplorerSchema from "discourse/plugins/discourse-data-explorer/discourse/components/explorer-schema";
import ParamInputForm from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";
import QueryAiPrompt from "discourse/plugins/discourse-data-explorer/discourse/components/query-ai-prompt";
import QueryModeSwitch from "discourse/plugins/discourse-data-explorer/discourse/components/query-mode-switch";
import QueryResultDownloadButtons from "discourse/plugins/discourse-data-explorer/discourse/components/query-result-download-buttons";
import QueryResultsWrapper from "discourse/plugins/discourse-data-explorer/discourse/components/query-results-wrapper";
import QueryRunSplitButton from "discourse/plugins/discourse-data-explorer/discourse/components/query-run-split-button";

const PaneSeparator = <template>
  <DResizeSeparator
    class="grippie"
    @axis="vertical"
    @label={{i18n "explorer.resize_editor"}}
    @max={{@controller.maxPaneHeight}}
    @measure={{@controller.panesFor}}
    @onResize={{@controller.onPaneResize}}
    @side="start"
  />
</template>;

export default class QueriesEdit extends Component {
  get showDestroyQuery() {
    return this.args.controller.model?.id > -1;
  }

  <template>
    <div class="admin-detail">
      {{#if @controller.disallow}}
        <h1>{{i18n "explorer.admins_only"}}</h1>
      {{else}}
        <div class="query-edit__top-bar">
          <BackButton
            @label="explorer.queries"
            @route="adminPlugins.show.explorer.index"
          />

          {{#if @controller.aiQueriesEnabled}}
            <QueryModeSwitch
              @editDisabled={{@controller.editDisabled}}
              @onChange={{@controller.setMode}}
              @value={{@controller.mode}}
            />
          {{/if}}
        </div>

        <div class="query-edit {{if @controller.editingName 'editing'}}">
          {{#if @controller.editingName}}
            <div class="name">
              <DButton
                class="btn-default previous"
                @action={{@controller.exitEdit}}
                @icon="xmark"
              />
              <div class="name-text-field">
                <DTextField
                  @onChange={{@controller.setDirty}}
                  @value={{@controller.model.name}}
                />
              </div>
            </div>

            <div class="desc">
              <DTextarea
                @input={{@controller.setDirty}}
                @placeholder={{i18n "explorer.description_placeholder"}}
                @value={{@controller.model.description}}
              />
            </div>
          {{else}}
            <div class="name">
              <h1 class="query-name-display">
                <span>{{@controller.model.name}}</span>
              </h1>
              {{#unless @controller.editDisabled}}
                <DButton
                  class="edit-query-name btn-transparent"
                  @action={{@controller.editName}}
                  @icon="pencil"
                />
              {{/unless}}
            </div>

            <div class="desc">{{@controller.model.description}}</div>
          {{/if}}

          {{#unless @controller.model.destroyed}}
            <div class="groups">
              <span class="label">{{i18n "explorer.allow_groups"}}</span>
              <span>
                <GroupChooser
                  @content={{@controller.groupOptions}}
                  @onChange={{@controller.updateGroupIds}}
                  @value={{@controller.model.group_ids}}
                />
              </span>
            </div>
          {{/unless}}

          <div class="clear"></div>

          {{#if (eq @controller.mode "ai")}}
            <QueryAiPrompt
              @disabled={{@controller.aiGenerating}}
              @generating={{@controller.aiGenerating}}
              @onChange={{@controller.updateAiPrompt}}
              @onRegenerate={{@controller.regenerate}}
              @regenerateDisabled={{@controller.regenerateDisabled}}
              @value={{@controller.aiPrompt}}
            />
          {{else}}
            <div class="query-editor {{if @controller.hideSchema 'no-schema'}}">
              <div class="query-editor__header">
                <h3 class="query-editor__label">{{i18n
                    "explorer.sql_label"
                  }}</h3>
              </div>

              {{#if @controller.editingQuery}}
                <div class="panels-flex query-editor__panes">
                  <div class="editor-panel">
                    <AceEditor
                      @content={{@controller.model.sql}}
                      @disabled={{@controller.editorDisabled}}
                      @mode="sql"
                      @onChange={{@controller.updateSql}}
                      @save={{@controller.save}}
                      @submit={{@controller.run}}
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

                <PaneSeparator @controller={{@controller}} />

                <div class="clear"></div>
              {{else}}
                <div class="sql">
                  <CodeView
                    @codeClass="sql"
                    @setDirty={{@controller.setDirty}}
                    @value={{@controller.model.sql}}
                  />
                </div>
              {{/if}}
            </div>
          {{/if}}

          {{#if @controller.model.is_default}}
            <div class="default-query-notice alert alert-info">{{i18n
                "explorer.default_query_notice"
              }}</div>
          {{/if}}
        </div>

        {{#if @controller.model.hasParams}}
          <form class="query-params-block" {{on "submit" @controller.run}}>
            <ParamInputForm
              @initialValues={{@controller.parsedParams}}
              @onRegisterApi={{@controller.onRegisterApi}}
              @paramInfo={{@controller.model.param_info}}
            />
          </form>
        {{/if}}

        <div class="query-action-bar">
          <div class="query-action-bar__left">
            <QueryRunSplitButton
              @disabled={{@controller.runDisabled}}
              @label={{@controller.runButtonLabel}}
              @onRun={{@controller.run}}
            />
            {{#if @controller.editingQuery}}
              <DButton
                class="btn-discard-query"
                @action={{@controller.discard}}
                @disabled={{@controller.saveDisabled}}
                @icon="arrow-rotate-left"
                @label="explorer.undo"
              />
              <DButton
                class="btn-transparent query-action-bar__help"
                @action={{@controller.showHelpModal}}
                @disabled={{@controller.actionsBusy}}
                @icon="circle-question"
                @label="explorer.help.label"
              />
            {{/if}}
          </div>

          <div class="query-action-bar__right">
            {{#if (or @controller.hasResults (eq @controller.mode "ai"))}}
              <DSegmentedControl
                class="query-results-modes"
                @items={{@controller.viewItems}}
                @name="query-result-view"
                @onSelect={{@controller.setView}}
                @translatedLabel={{i18n "explorer.view.label"}}
                @value={{@controller.view}}
              />
            {{/if}}
            <QueryResultDownloadButtons
              @content={{@controller.results}}
              @includeQueryExport={{true}}
              @query={{@controller.model}}
            />

            {{#if @controller.model.destroyed}}
              <DButton
                @action={{@controller.recover}}
                @disabled={{@controller.actionsBusy}}
                @icon="arrow-rotate-left"
                @label="explorer.recover"
              />
            {{else if this.showDestroyQuery}}
              <DButton
                class="btn-danger"
                @action={{@controller.destroyQuery}}
                @disabled={{@controller.actionsBusy}}
                @icon="trash-can"
                @label="explorer.delete"
              />
            {{/if}}
          </div>
        </div>

        <div hidden {{didInsert @controller.runOnLoad}}></div>

        <DConditionalLoadingSpinner @condition={{@controller.loading}} />

        {{#if (and (eq @controller.mode "ai") (eq @controller.view "sql"))}}
          <div class="query-editor {{if @controller.hideSchema 'no-schema'}}">
            <div class="query-editor__header">
              <h3 class="query-editor__label">{{i18n "explorer.sql_label"}}</h3>
            </div>

            {{#if @controller.editingQuery}}
              <div class="panels-flex query-editor__panes">
                <div class="editor-panel">
                  <AceEditor
                    @content={{@controller.model.sql}}
                    @disabled={{@controller.editorDisabled}}
                    @mode="sql"
                    @onChange={{@controller.updateSql}}
                    @save={{@controller.save}}
                    @submit={{@controller.run}}
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

              <PaneSeparator @controller={{@controller}} />

              <div class="clear"></div>
            {{else}}
              <div class="sql">
                <CodeView
                  @codeClass="sql"
                  @setDirty={{@controller.setDirty}}
                  @value={{@controller.model.sql}}
                />
              </div>
            {{/if}}
          </div>
        {{/if}}

        {{#if (notEq @controller.view "sql")}}
          <QueryResultsWrapper
            @cachedAt={{@controller.cachedAt}}
            @content={{@controller.results}}
            @hideHeaderActions={{true}}
            @onSetView={{@controller.setView}}
            @query={{@controller.model}}
            @results={{@controller.results}}
            @showResults={{@controller.showResults}}
            @view={{@controller.view}}
          />
        {{/if}}

      {{/if}}
    </div>
  </template>
}
