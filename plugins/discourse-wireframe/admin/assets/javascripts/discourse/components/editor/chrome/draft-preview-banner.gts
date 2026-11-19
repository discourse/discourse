import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import type WireframeDraftPreviewService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-draft-preview";

/**
 * Tells an admin the page shows an unpublished layout only they can see, with
 * links to keep editing it or return to the live site.
 */
export default class DraftPreviewBanner extends Component {
  @service declare wireframeDraftPreview: WireframeDraftPreviewService;

  // A full load clears the previewed layers; an in-app link would keep them.
  @action
  go(url: string): void {
    window.location.assign(url);
  }

  @action
  exit(): void {
    this.go(this.wireframeDraftPreview.exitUrl());
  }

  <template>
    {{#if this.wireframeDraftPreview.active}}
      <div class="wireframe-draft-preview" role="status">
        <span
          class="wireframe-status-chip --draft wireframe-draft-preview__badge"
        >
          <span aria-hidden="true" class="wireframe-status-chip__dot"></span>
          <span class="wireframe-status-chip__label">{{i18n
              "wireframe.status.draft"
            }}</span>
        </span>
        <span class="wireframe-draft-preview__text">{{i18n
            "wireframe.preview.banner"
            name=this.wireframeDraftPreview.designName
          }}</span>
        <button
          class="btn-link wireframe-draft-preview__link --exit"
          type="button"
          {{on "click" this.exit}}
        >{{i18n "wireframe.preview.exit"}}</button>
      </div>
    {{/if}}
  </template>
}
