import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import AceEditor from "discourse/components/ace-editor";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DTextarea from "discourse/components/d-textarea";
import TextField from "discourse/components/text-field";
import icon from "discourse/helpers/d-icon";
import draggable from "discourse/modifiers/draggable";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { i18n } from "discourse-i18n";
import CodeView from "../../../../components/code-view";
import ExplorerSchema from "../../../../components/explorer-schema";
import ParamInputForm from "../../../../components/param-input-form";
import QueryResultsWrapper from "../../../../components/query-results-wrapper";

export default class QueriesDetails extends Component {
  get showDestroyQuery() {
    return this.args.controller.model?.id > -1;
  }

  <template>
    {{#if @controller.disallow}}
      <h1>{{i18n "explorer.admins_only"}}</h1>
    {{else}}

      <div class="query-edit {{if @controller.editingName 'editing'}}">
        {{#if @controller.editingName}}
          <div class="name">
            <DButton
              @action={{@controller.goHome}}
              @icon="chevron-left"
              class="previous"
            />
            <DButton
              @action={{@controller.exitEdit}}
              @icon="xmark"
              class="previous"
            />
            <div class="name-text-field">
              <TextField
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
            <DButton
              @action={{@controller.goHome}}
              @icon="chevron-left"
              class="previous"
            />

            <h1>
              <span>{{@controller.model.name}}</span>
              {{#unless @controller.editDisabled}}
                <DButton
                  @action={{@controller.editName}}
                  @icon="pencil"
                  class="edit-query-name btn-transparent"
                />
              {{/unless}}
            </h1>
          </div>

          <div class="desc">
            {{@controller.model.description}}
          </div>
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

        {{#if @controller.editingQuery}}
          <div class="query-editor {{if @controller.hideSchema 'no-schema'}}">
            <div class="panels-flex">
              <div class="editor-panel">
                <AceEditor
                  {{on "click" @controller.setDirty}}
                  @content={{@controller.model.sql}}
                  @onChange={{fn (mut @controller.model.sql)}}
                  @mode="sql"
                  @disabled={{@controller.model.destroyed}}
                  @save={{@controller.save}}
                  @submit={{@controller.saveAndRun}}
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
              {{draggable
                didStartDrag=@controller.didStartDrag
                didEndDrag=@controller.didEndDrag
                dragMove=@controller.dragMove
              }}
            >
              {{icon "discourse-expand"}}
            </div>

            <div class="clear"></div>
          </div>
        {{else}}
          <div class="sql">
            <CodeView
              @value={{@controller.model.sql}}
              @codeClass="sql"
              @setDirty={{@controller.setDirty}}
            />
          </div>
        {{/if}}

        <div class="clear"></div>

        <div class="pull-left left-buttons">
          {{#if @controller.editingQuery}}
            <DButton
              class="btn-save-query"
              @action={{@controller.save}}
              @label="explorer.save"
              @disabled={{@controller.saveDisabled}}
            />
          {{else}}
            {{#unless @controller.editDisabled}}
              <DButton
                class="btn-edit-query"
                @action={{@controller.editQuery}}
                @label="explorer.edit"
                @icon="pencil"
              />
            {{/unless}}
          {{/if}}

          <DButton
            @action={{@controller.download}}
            @label="explorer.export"
            @disabled={{@controller.runDisabled}}
            @icon="download"
          />

          {{#if @controller.editingQuery}}
            <DButton
              @action={{@controller.showHelpModal}}
              @label="explorer.help.label"
              @icon="circle-question"
            />
          {{/if}}
        </div>

        <div class="pull-right right-buttons">
          {{#if @controller.model.destroyed}}
            <DButton
              @action={{@controller.recover}}
              @icon="arrow-rotate-left"
              @label="explorer.recover"
            />
          {{else}}
            {{#if @controller.editingQuery}}
              <DButton
                @action={{@controller.discard}}
                @icon="arrow-rotate-left"
                @label="explorer.undo"
                @disabled={{@controller.saveDisabled}}
              />
            {{/if}}

            {{#if this.showDestroyQuery}}
              <DButton
                @action={{@controller.destroyQuery}}
                @icon="trash-can"
                @label="explorer.delete"
                class="btn-danger"
              />
            {{/if}}
          {{/if}}
        </div>
        <div class="clear"></div>
      </div>

      <form class="query-run" {{on "submit" @controller.run}}>
        {{#if @controller.model.hasParams}}
          <ParamInputForm
            @initialValues={{@controller.parsedParams}}
            @paramInfo={{@controller.model.param_info}}
            @onRegisterApi={{@controller.onRegisterApi}}
          />
        {{/if}}

        {{#if @controller.runDisabled}}
          {{#if @controller.saveDisabled}}
            <DButton
              @label="explorer.run"
              @disabled="true"
              class="btn-primary"
            />
          {{else}}
            <DButton
              @action={{@controller.saveAndRun}}
              @icon="play"
              @label="explorer.saverun"
              class="btn-primary"
            />
          {{/if}}
        {{else}}
          <DButton
            {{didInsert @controller.runOnLoad}}
            @action={{@controller.run}}
            @icon="play"
            @label="explorer.run"
            @disabled={{@controller.runDisabled}}
            @type="submit"
            class="btn-primary"
          />
        {{/if}}

        <label class="query-plan">
          <Input
            @type="checkbox"
            @checked={{@controller.explain}}
            name="explain"
          />
          {{i18n "explorer.explain_label"}}
        </label>
      </form>
      <hr />

      <ConditionalLoadingSpinner @condition={{@controller.loading}} />

      <QueryResultsWrapper
        @results={{@controller.results}}
        @showResults={{@controller.showResults}}
        @query={{@controller.model}}
        @content={{@controller.results}}
      />
    {{/if}}
  </template>
}
