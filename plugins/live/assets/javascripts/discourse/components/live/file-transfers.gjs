import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import LiveFileTransfer from "./file-transfer.gjs";

// Rendered globally, independently of the room page, widget and dropdowns.
export default class LiveFileTransfers extends Component {
  @service liveWebrtc;

  @tracked collapsed = false;
  @tracked collapsedOfferIds = [];

  get pendingOffers() {
    return this.liveWebrtc.fileTransfers.filter(
      (transfer) =>
        transfer.direction === "incoming" && transfer.status === "pending"
    );
  }

  get expanded() {
    // New offers need attention, but progress updates should not undo the
    // user's choice to collapse offers they have already seen.
    return (
      !this.collapsed ||
      this.pendingOffers.some(
        (transfer) => !this.collapsedOfferIds.includes(transfer.id)
      )
    );
  }

  @action
  toggleExpanded() {
    const collapse = this.expanded;
    this.collapsedOfferIds = this.pendingOffers.map((transfer) => transfer.id);
    this.collapsed = collapse;
  }

  <template>
    {{#if this.liveWebrtc.fileTransfers.length}}
      <section
        aria-label={{i18n "live.file_transfer.title"}}
        class="live-file-transfers"
      >
        <div class="live-file-transfers__header">
          <div>
            <h2>{{i18n "live.file_transfer.title"}}</h2>
            <span class="live-file-transfers__summary" role="status">{{i18n
                "live.file_transfer.pending_count"
                count=this.pendingOffers.length
              }}</span>
          </div>
          <DButton
            aria-controls="live-file-transfers-list"
            aria-expanded={{if this.expanded "true" "false"}}
            class="live-file-transfers__toggle"
            @action={{this.toggleExpanded}}
            @label={{if
              this.expanded
              "live.file_transfer.collapse"
              "live.file_transfer.expand"
            }}
          />
        </div>
        <ul hidden={{not this.expanded}} id="live-file-transfers-list">
          {{#each this.liveWebrtc.fileTransfers key="id" as |transfer|}}
            <LiveFileTransfer @transfer={{transfer}} />
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
