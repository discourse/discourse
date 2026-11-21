import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Badge from "discourse/models/badge";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class PmBadgeHolderPicker extends Component {
  @service composer;

  @tracked badges = [];
  @tracked badgeId;
  @tracked loading = true;
  @tracked adding = false;
  @tracked error;

  get addDisabled() {
    return !this.badgeId || this.adding;
  }

  @action
  async loadBadges() {
    try {
      this.badges = (await Badge.findAll()).filter((badge) => badge.enabled);
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async addRecipients() {
    this.adding = true;
    this.error = null;

    try {
      const { usernames } = await ajax(
        `/badges/${this.badgeId}/recipients/for-message.json`
      );
      const draft = this.args.model.composer;
      if (
        this.isDestroying ||
        this.composer.model !== draft ||
        !draft.creatingPrivateMessage
      ) {
        return;
      }

      if (!usernames.length) {
        this.error = i18n("composer.badge_holder_picker.no_recipients");
        return;
      }

      const existing = (draft.targetRecipients || "")
        .split(",")
        .filter(Boolean);
      const names = new Set(existing.map((name) => name.toLowerCase()));
      const additional = usernames.filter(
        (name) => !names.has(name.toLowerCase())
      );
      draft.set("targetRecipients", existing.concat(additional).join(","));
      this.args.closeModal();
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.adding = false;
    }
  }

  <template>
    <DModal
      class="pm-badge-holder-picker"
      @closeModal={{@closeModal}}
      @flash={{this.error}}
      @flashType="error"
      @title={{i18n "composer.add_badge_holders"}}
      {{didInsert this.loadBadges}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.badges.length}}
            <ComboBox
              @content={{this.badges}}
              @onChange={{fn (mut this.badgeId)}}
              @options={{hash
                disabled=this.adding
                filterable=true
                none="composer.badge_holder_picker.select_badge"
              }}
              @value={{this.badgeId}}
            />
          {{else}}
            {{#unless this.error}}
              <p>{{i18n "composer.badge_holder_picker.no_badges"}}</p>
            {{/unless}}
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.addRecipients}}
          @disabled={{this.addDisabled}}
          @label="composer.add_badge_holders"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
