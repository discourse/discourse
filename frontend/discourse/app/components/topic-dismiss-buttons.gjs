import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  canDismissNewAndStopTracking,
  dismissNewLabel,
  dismissNewOptions,
  dismissReadLabel,
  newListSubset,
  showDismissReadModal,
} from "discourse/lib/topic-dismiss";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class TopicDismissButtons extends Component {
  @service currentUser;
  @service modal;
  @service site;

  dMenu;

  get showBasedOnPosition() {
    return this.args.position === "top" || this.args.model.topics.length > 5;
  }

  get selectedCount() {
    return this.args.selectedTopics.length;
  }

  get dismissLabel() {
    return dismissReadLabel(this.selectedCount);
  }

  get dismissNewLabel() {
    return dismissNewLabel({
      unifiedNew: this.currentUser?.unified_new_enabled,
      subset: this.newListSubset,
      selectedCount: this.selectedCount,
    });
  }

  get newListSubset() {
    return newListSubset(this.args.model);
  }

  get showDismissNewMenu() {
    // On mobile the bottom dismiss button is the floating control, so the
    // stop-tracking menu only renders on the top button.
    return (
      canDismissNewAndStopTracking(this.newListSubset) &&
      !(this.site.mobileView && this.args.position === "bottom")
    );
  }

  @action
  dismissReadPosts() {
    showDismissReadModal(this.modal, {
      selectedCount: this.selectedCount,
      dismissRead: this.args.dismissRead,
    });
  }

  @action
  registerDMenu(api) {
    this.dMenu = api;
  }

  @action
  dismissNew(untrack = false) {
    this.args.resetNew({ ...dismissNewOptions(this.newListSubset), untrack });
  }

  @action
  async dismissNewAndStopTracking() {
    await this.dMenu?.close();
    this.dismissNew(true);
  }

  <template>
    {{~#if this.showBasedOnPosition~}}
      <div class="row dismiss-container-{{@position}}">
        {{~#if @showDismissRead~}}
          <DButton
            class="btn-default dismiss-read"
            id="dismiss-topics-{{@position}}"
            @action={{this.dismissReadPosts}}
            @title="topics.bulk.dismiss_tooltip"
            @translatedLabel={{this.dismissLabel}}
          />
        {{~/if~}}
        {{~#if @showResetNew~}}
          {{#if @showNewDismissCombo}}
            <DComboButton
              class="topic-dismiss-buttons__combo"
              @btnTypeClass="btn-default dismiss-read"
              @hasMenu={{this.showDismissNewMenu}}
              as |combo|
            >
              <combo.Button
                class="topic-dismiss-buttons__button"
                id="dismiss-new-{{@position}}"
                @action={{this.dismissNew}}
                @translatedLabel={{this.dismissNewLabel}}
              />

              <combo.Menu
                aria-label={{i18n "topics.bulk.dismiss_new_menu"}}
                class="topic-dismiss-buttons__menu"
                id="dismiss-new-menu-{{@position}}"
                @identifier="dismiss-new-menu"
                @modalForMobile={{true}}
                @onRegisterApi={{this.registerDMenu}}
              >
                <DDropdownMenu as |dropdown|>
                  <dropdown.item class="topic-dismiss-buttons__menu-item">
                    <DButton
                      class="dismiss-new-stop-tracking"
                      @action={{this.dismissNewAndStopTracking}}
                      @translatedLabel={{i18n
                        "topics.bulk.dismiss_and_stop_tracking"
                      }}
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </combo.Menu>
            </DComboButton>
          {{else}}
            <DButton
              class="btn-default dismiss-read"
              id="dismiss-new-{{@position}}"
              @action={{@resetNew}}
              @icon="check"
              @translatedLabel={{this.dismissNewLabel}}
            />
          {{/if}}
        {{~/if~}}
      </div>
    {{~/if~}}
  </template>
}
