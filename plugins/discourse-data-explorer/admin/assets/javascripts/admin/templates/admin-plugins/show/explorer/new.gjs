import { on } from "@ember/modifier";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DTextField from "discourse/ui-kit/d-text-field";
import DTextarea from "discourse/ui-kit/d-textarea";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import QueryModeSwitch from "discourse/plugins/discourse-data-explorer/discourse/components/query-mode-switch";

export default <template>
  <div class="admin-detail">
    <div class="query-new__top-bar">
      <BackButton
        @route="adminPlugins.show.explorer.index"
        @label="explorer.queries"
      />

      {{#if @controller.aiQueriesEnabled}}
        <QueryModeSwitch
          @value={{@controller.mode}}
          @onChange={{@controller.setMode}}
        />
      {{/if}}
    </div>

    {{#if @controller.aiQueriesEnabled}}
      <div class="query-new query-new--ai-first">
        {{#if (eq @controller.mode "ai")}}
          <div class="query-new__ai-section">
            <label class="query-new__ai-label">
              <span>{{i18n "explorer.ai.description_title"}}</span>
              {{dIcon "discourse-sparkles"}}
            </label>

            <p class="query-new__ai-hint">
              {{i18n "explorer.ai.description_hint"}}
            </p>

            <DTextarea
              @value={{@controller.aiDescription}}
              {{on "input" @controller.updateAiDescription}}
              {{on "keydown" @controller.handleKeydown}}
              placeholder={{i18n "explorer.ai.description_placeholder"}}
              class="query-new__ai-textarea"
              disabled={{@controller.aiGenerating}}
            />

            <div class="query-new__ai-actions">
              {{#if @controller.hasGenerated}}
                <DButton
                  @action={{@controller.generate}}
                  @icon="discourse-sparkles"
                  @label="explorer.ai.regenerate"
                  @disabled={{@controller.aiGenerating}}
                  class="btn-default query-new__regenerate-btn"
                />
              {{else}}
                <DButton
                  @action={{@controller.generate}}
                  @label="explorer.ai.generate"
                  @disabled={{@controller.aiGenerating}}
                  class="btn-primary query-new__generate-btn"
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
            </div>
          </div>

          {{#if @controller.hasGenerated}}
            <hr class="query-new__divider" />

            <label class="query-new__field-label">
              {{i18n "explorer.ai.sql_label"}}
            </label>
            <div class="query-new__sql-editor">
              <AceEditor
                @content={{@controller.generatedSql}}
                @onChange={{@controller.updateSql}}
                @mode="sql"
              />
            </div>

            <div class="query-new__fields">
              <label class="query-new__field-label">
                {{i18n "explorer.query_name"}}
              </label>
              <DTextField
                @value={{@controller.generatedName}}
                @onChange={{@controller.updateName}}
                class="query-new__name-input"
              />

              <label class="query-new__field-label">
                {{i18n "explorer.description_placeholder"}}
                <span class="query-new__optional">
                  ({{i18n "explorer.ai.optional"}})
                </span>
              </label>
              <DTextarea
                @value={{@controller.generatedDescription}}
                {{on "input" @controller.updateDescription}}
                class="query-new__description-input"
              />
            </div>

            <div class="query-new__actions">
              <DButton
                @action={{@controller.saveQuery}}
                @label="explorer.ai.save_query"
                @disabled={{@controller.aiGenerating}}
                class="btn-default"
              />
            </div>
          {{/if}}
        {{/if}}

        {{#if (eq @controller.mode "manual")}}
          <Form
            @data={{@controller.model}}
            @onSubmit={{@controller.create}}
            class="query-new__manual-form"
            as |form|
          >
            <form.Field
              @name="name"
              @title={{i18n "explorer.query_name"}}
              @validation="required"
              @format="large"
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>
            <form.Field
              @name="description"
              @title={{i18n "explorer.description_placeholder"}}
              @format="large"
              @type="textarea"
              as |field|
            >
              <field.Control />
            </form.Field>
            <form.Actions>
              <form.Submit @label="explorer.create" @icon="plus" />
            </form.Actions>
          </Form>
        {{/if}}
      </div>
    {{else}}
      <Form
        @data={{@controller.model}}
        @onSubmit={{@controller.create}}
        class="query-new"
        as |form|
      >
        <form.Field
          @name="name"
          @title={{i18n "explorer.query_name"}}
          @validation="required"
          @format="large"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>
        <form.Field
          @name="description"
          @title={{i18n "explorer.description_placeholder"}}
          @format="large"
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>
        <form.Actions>
          <form.Submit @label="explorer.create" @icon="plus" />
        </form.Actions>
      </Form>
    {{/if}}
  </div>
</template>
