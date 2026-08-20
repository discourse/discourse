import { fn, hash } from "@ember/helper";
import { i18n } from "discourse-i18n";

const statusLabel = (status) =>
  i18n(`discourse_ai.rag.sources.status.${status || "pending"}`);

const RagDocumentSources = <template>
  <div class="rag-document-sources" ...attributes>
    <@form.Collection
      @name="rag_document_sources"
      as |source sourceIndex sourceData|
    >
      <@form.Row as |row|>
        <row.Col @size={{7}}>
          <source.Field
            @name="url"
            @title={{i18n "discourse_ai.rag.sources.url"}}
            @validation="required|url"
            @disabled={{@disabled}}
            @type="input-url"
            as |field|
          >
            <field.Control @maxlength="2000" />
          </source.Field>
        </row.Col>

        <row.Col @size={{4}}>
          <source.Field
            @name="refresh_interval_hours"
            @title={{i18n "discourse_ai.rag.sources.refresh_interval_hours"}}
            @disabled={{@disabled}}
            @type="input-number"
            as |field|
          >
            <field.Control @min={{1}} @max={{8760}} />
          </source.Field>
        </row.Col>

        <row.Col @size={{1}}>
          {{#unless @disabled}}
            <@form.Button
              class="btn-danger"
              @icon="trash-can"
              @title="discourse_ai.rag.sources.remove"
              @action={{fn source.remove sourceIndex}}
            />
          {{/unless}}
        </row.Col>
      </@form.Row>

      {{#if sourceData.last_error}}
        <@form.Alert @icon="triangle-exclamation" @type="error">
          {{i18n
            "discourse_ai.rag.sources.last_error"
            error=sourceData.last_error
          }}
        </@form.Alert>
      {{else}}
        <@form.Alert @icon="circle-info" @type="info">
          {{statusLabel sourceData.indexing_status}}
        </@form.Alert>
      {{/if}}
    </@form.Collection>

    {{#unless @disabled}}
      <@form.Button
        class="btn-default"
        @icon="plus"
        @label="discourse_ai.rag.sources.add"
        @action={{fn
          @form.addItemToCollection
          "rag_document_sources"
          (hash url="" refresh_interval_hours=24)
        }}
      />
    {{/unless}}
  </div>
</template>;

export default RagDocumentSources;
