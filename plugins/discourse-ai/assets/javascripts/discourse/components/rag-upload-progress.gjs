import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class RagUploadProgress extends Component {
  @service messageBus;

  @tracked updatedProgress = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(`/discourse-ai/rag/${this.args.upload.id}`);
  }

  @action
  trackProgress() {
    this.messageBus.subscribe(
      `/discourse-ai/rag/${this.args.upload.id}`,
      this.onIndexingUpdate
    );
  }

  @bind
  onIndexingUpdate(data) {
    // Order not guaranteed. Discard old updates.
    if (
      !this.updatedProgress ||
      this.updatedProgress.left === 0 ||
      this.updatedProgress.left > data.left ||
      data.total === data.indexed
    ) {
      this.updatedProgress = data;
    }
  }

  get calculateProgress() {
    if (this.progress.total === 0) {
      return 0;
    }

    return Math.ceil((this.progress.indexed * 100) / this.progress.total);
  }

  get fullyIndexed() {
    return (
      this.progress && this.progress.total !== 0 && this.progress.left === 0
    );
  }

  get progress() {
    if (this.updatedProgress) {
      return this.updatedProgress;
    } else if (this.args.ragIndexingStatuses) {
      return this.args.ragIndexingStatuses[this.args.upload.id];
    } else {
      return [];
    }
  }

  <template>
    <td class="rag-uploader__upload-status" {{didInsert this.trackProgress}}>
      {{#if this.progress}}
        {{#if this.fullyIndexed}}
          <span class="indexed">
            {{icon "check"}}
            {{i18n "discourse_ai.rag.uploads.indexed"}}
          </span>
        {{else}}
          <span class="indexing">
            {{icon "robot"}}
            {{i18n "discourse_ai.rag.uploads.indexing"}}
            {{this.calculateProgress}}%
          </span>
        {{/if}}
      {{else}}
        <span class="uploaded">{{i18n
            "discourse_ai.rag.uploads.uploaded"
          }}</span>
      {{/if}}
    </td>
  </template>
}
