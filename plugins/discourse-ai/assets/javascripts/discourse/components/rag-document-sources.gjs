import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import RagDocumentSourcesModal from "./modal/rag-document-sources-modal";

const SUMMARY_URL_LIMIT = 3;

export default class RagDocumentSources extends Component {
  @service modal;

  get sources() {
    return this.args.sources || [];
  }

  get summarySources() {
    return this.sources.slice(0, SUMMARY_URL_LIMIT);
  }

  get remainingSourceCount() {
    return Math.max(this.sources.length - SUMMARY_URL_LIMIT, 0);
  }

  get buttonLabel() {
    return this.sources.length
      ? "discourse_ai.rag.sources.edit"
      : "discourse_ai.rag.sources.add";
  }

  @action
  openEditor() {
    const currentSources = this.sources;

    this.modal.show(RagDocumentSourcesModal, {
      model: {
        sources: currentSources,
        onSave: ({ urls, refreshIntervalHours }) => {
          const existingSources = new Map(
            currentSources.map((source) => [source.url, source])
          );
          const updatedSources = urls.map((url) => ({
            ...existingSources.get(url),
            url,
            refresh_interval_hours: refreshIntervalHours,
          }));

          this.args.form.set("rag_document_sources", updatedSources);
        },
      },
    });
  }

  <template>
    <div class="rag-document-sources" ...attributes>
      {{#unless @isNew}}
        {{#if this.sources.length}}
          <p class="rag-document-sources__count">
            {{i18n
              "discourse_ai.rag.sources.summary"
              count=this.sources.length
            }}
          </p>
          <ul class="rag-document-sources__list">
            {{#each this.summarySources as |source|}}
              <li class="rag-document-sources__url">{{source.url}}</li>
            {{/each}}
          </ul>
          {{#if this.remainingSourceCount}}
            <p class="rag-document-sources__remaining">
              {{i18n
                "discourse_ai.rag.sources.more"
                count=this.remainingSourceCount
              }}
            </p>
          {{/if}}
        {{else}}
          <p class="rag-document-sources__empty">
            {{i18n "discourse_ai.rag.sources.empty"}}
          </p>
        {{/if}}
      {{/unless}}

      {{#unless @disabled}}
        <DButton
          class="btn-default rag-document-sources__edit"
          @action={{this.openEditor}}
          @icon={{if this.sources.length "pencil" "plus"}}
          @label={{this.buttonLabel}}
        />
      {{/unless}}
    </div>
  </template>
}
