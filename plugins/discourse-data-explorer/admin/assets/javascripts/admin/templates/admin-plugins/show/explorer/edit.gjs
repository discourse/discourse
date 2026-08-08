import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import DSegmentedControl from "discourse/components/d-segmented-control";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { and, eq, notEq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DTextField from "discourse/ui-kit/d-text-field";
import DTextarea from "discourse/ui-kit/d-textarea";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";
import CodeView from "discourse/plugins/discourse-data-explorer/discourse/components/code-view";
import ExplorerSchema from "discourse/plugins/discourse-data-explorer/discourse/components/explorer-schema";
import ParamInputForm from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";
import QueryAiPrompt from "discourse/plugins/discourse-data-explorer/discourse/components/query-ai-prompt";
import QueryModeSwitch from "discourse/plugins/discourse-data-explorer/discourse/components/query-mode-switch";
import QueryResultDownloadButtons from "discourse/plugins/discourse-data-explorer/discourse/components/query-result-download-buttons";
import QueryResultsWrapper from "discourse/plugins/discourse-data-explorer/discourse/components/query-results-wrapper";
import QueryRunSplitButton from "discourse/plugins/discourse-data-explorer/discourse/components/query-run-split-button";

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
            @route="adminPlugins.show.explorer.index"
            @label="explorer.queries"
          />

          {{#if @controller.aiQueriesEnabled}}
            <QueryModeSwitch
              @value={{@controller.mode}}
              @onChange={{@controller.setMode}}
              @editDisabled={{@controller.editDisabled}}
            />
          {{/if}}
        </div>

        <div class="query-edit {{if @controller.editingName 'editing'}}">
          {{#if @controller.editingName}}
            <div class="name">
              <DButton
                @action={{@controller.exitEdit}}
                @icon="xmark"
                class="previous"
              />
              <div class="name-text-field">
                <DTextField
                  @value={{@controller.model.name}}
                  @onChange={{@controller.setDirty}}
                />
              </div>
            </div>

            <div class="desc">
              <DTextarea
                @value={{@controller.model.description}}
                @placeholder={{i18n "explorer.description_placeholder"}}
                @input={{@controller.setDirty}}
              />
            </div>
          {{else}}
            <div class="name">
              <h1 class="query-name-display">
                <span>{{@controller.model.name}}</span>
              </h1>
              {{#unless @controller.editDisabled}}
                <DButton
                  @action={{@controller.editName}}
                  @icon="pencil"
                  class="edit-query-name btn-transparent"
                />
              {{/unless}}
            </div>

            <div class="desc">{{@controller.model.description}}</div>
          {{/if}}

          {{#unless @controller.model.destroyed}}
            <div class="groups">
              <span class="label">{{i18n "explorer.allow_groups"}}</span>
              <span>
                <MultiSelect
                  @value={{@controller.model.group_ids}}
                  @content={{@controller.groupOptions}}
                  @options={{hash allowAny=false}}
                  @onChange={{@controller.updateGroupIds}}
                />
              </span>
            </div>
          {{/unless}}

          <div class="clear"></div>

          {{#if (eq @controller.mode "ai")}}
            <QueryAiPrompt
              @value={{@controller.aiPrompt}}
              @onChange={{@controller.updateAiPrompt}}
              @onRegenerate={{@controller.regenerate}}
              @regenerateDisabled={{@controller.regenerateDisabled}}
              @generating={{@controller.aiGenerating}}
              @disabled={{@controller.aiGenerating}}
            />
          {{else}}
            <div class="query-editor {{if @controller.hideSchema 'no-schema'}}">
              <div class="query-editor__header">
                <h3 class="query-editor__label">{{i18n
                    "explorer.sql_label"
                  }}</h3>
              </div>

              {{#if @controller.editingQuery}}
                <div class="panels-flex">
                  <div class="editor-panel">
                    <AceEditor
                      @content={{@controller.model.sql}}
                      @onChange={{@controller.updateSql}}
                      @mode="sql"
                      @disabled={{@controller.editorDisabled}}
                      @save={{@controller.save}}
                      @submit={{@controller.run}}
                    />
                  </div>

                  <div class="right-panel">
                    <ExplorerSchema
                      @schema={{@controller.schema}}
                      @hideSchema={{@controller.hideSchema}}
                      @updateHideSchema={{@controller.updateHideSchema}}
                    />
                  </div>
                </div>

                <div
                  class="grippie"
                  {{dPointerDrag
                    onDragStart=@controller.didStartDrag
                    onDrag=@controller.dragMove
                    onDragEnd=@controller.didEndDrag
                  }}
                >
                </div>

                <div class="clear"></div>
              {{else}}
                <div class="sql">
                  <CodeView
                    @value={{@controller.model.sql}}
                    @codeClass="sql"
                    @setDirty={{@controller.setDirty}}
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
              @paramInfo={{@controller.model.param_info}}
              @onRegisterApi={{@controller.onRegisterApi}}
            />
          </form>
        {{/if}}

        <div class="query-action-bar">
          <div class="query-action-bar__left">
            <QueryRunSplitButton
              @onRun={{@controller.run}}
              @disabled={{@controller.runDisabled}}
              @label={{@controller.runButtonLabel}}
            />
            {{#if @controller.editingQuery}}
              <DButton
                @action={{@controller.discard}}
                @icon="arrow-rotate-left"
                @label="explorer.undo"
                @disabled={{@controller.saveDisabled}}
                class="btn-discard-query"
              />
              <DButton
                @action={{@controller.showHelpModal}}
                @label="explorer.help.label"
                @icon="circle-question"
                @disabled={{@controller.actionsBusy}}
                class="btn-transparent query-action-bar__help"
              />
            {{/if}}
          </div>

          <div class="query-action-bar__right">
            {{#if (or @controller.hasResults (eq @controller.mode "ai"))}}
              <DSegmentedControl
                @name="query-result-view"
                @value={{@controller.view}}
                @items={{@controller.viewItems}}
                @onSelect={{@controller.setView}}
                @translatedLabel={{i18n "explorer.view.label"}}
                class="query-results-modes"
              />
            {{/if}}
            <QueryResultDownloadButtons
              @query={{@controller.model}}
              @content={{@controller.results}}
              @includeQueryExport={{true}}
            />

            {{#if @controller.model.destroyed}}
              <DButton
                @action={{@controller.recover}}
                @icon="arrow-rotate-left"
                @label="explorer.recover"
                @disabled={{@controller.actionsBusy}}
              />
            {{else if this.showDestroyQuery}}
              <DButton
                @action={{@controller.destroyQuery}}
                @icon="trash-can"
                @label="explorer.delete"
                @disabled={{@controller.actionsBusy}}
                class="btn-danger"
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
              <div class="panels-flex">
                <div class="editor-panel">
                  <AceEditor
                    @content={{@controller.model.sql}}
                    @onChange={{@controller.updateSql}}
                    @mode="sql"
                    @disabled={{@controller.editorDisabled}}
                    @save={{@controller.save}}
                    @submit={{@controller.run}}
                  />
                </div>

                <div class="right-panel">
                  <ExplorerSchema
                    @schema={{@controller.schema}}
                    @hideSchema={{@controller.hideSchema}}
                    @updateHideSchema={{@controller.updateHideSchema}}
                  />
                </div>
              </div>

              <div
                class="grippie"
                {{dPointerDrag
                  onDragStart=@controller.didStartDrag
                  onDrag=@controller.dragMove
                  onDragEnd=@controller.didEndDrag
                }}
              >
                {{dIcon "discourse-expand"}}
              </div>

              <div class="clear"></div>
            {{else}}
              <div class="sql">
                <CodeView
                  @value={{@controller.model.sql}}
                  @codeClass="sql"
                  @setDirty={{@controller.setDirty}}
                />
              </div>
            {{/if}}
          </div>
        {{/if}}

        {{#if (notEq @controller.view "sql")}}
          <QueryResultsWrapper
            @results={{@controller.results}}
            @showResults={{@controller.showResults}}
            @query={{@controller.model}}
            @content={{@controller.results}}
            @cachedAt={{@controller.cachedAt}}
            @view={{@controller.view}}
            @onSetView={{@controller.setView}}
            @hideHeaderActions={{true}}
          />
        {{/if}}

      {{/if}}
    </div>
  </template>
}
