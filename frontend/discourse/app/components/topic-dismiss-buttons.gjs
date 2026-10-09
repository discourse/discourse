import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DismissReadModal from "discourse/components/modal/dismiss-read";
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

  get dismissLabel() {
    if (this.args.selectedTopics.length === 0) {
      return i18n("topics.bulk.dismiss_button");
    }

    return i18n("topics.bulk.dismiss_button_with_selected", {
      count: this.args.selectedTopics.length,
    });
  }

  get dismissNewLabel() {
    if (this.currentUser?.unified_new_enabled) {
      switch (this.newListSubset) {
        case "topics":
          if (this.args.selectedTopics.length > 0) {
            return i18n("topics.bulk.dismiss_new_topics_with_selected", {
              count: this.args.selectedTopics.length,
            });
          }
          return i18n("topics.bulk.dismiss_new_topics");
        case "replies":
          if (this.args.selectedTopics.length > 0) {
            return i18n("topics.bulk.dismiss_new_replies_with_selected", {
              count: this.args.selectedTopics.length,
            });
          }
          return i18n("topics.bulk.dismiss_new_replies");
        default:
          if (this.args.selectedTopics.length > 0) {
            return i18n("topics.bulk.dismiss_all_with_selected", {
              count: this.args.selectedTopics.length,
            });
          }
          return i18n("topics.bulk.dismiss_all");
      }
    }

    if (this.args.selectedTopics.length === 0) {
      return i18n("topics.bulk.dismiss_new");
    }

    return i18n("topics.bulk.dismiss_new_with_selected", {
      count: this.args.selectedTopics.length,
    });
  }

  get newListSubset() {
    return (
      this.args.model?.params?.subset ?? this.args.model?.listParams?.subset
    );
  }

  get showDismissNewStopTracking() {
    return this.newListSubset !== "topics";
  }

  get showDismissNewMenu() {
    // On mobile the bottom dismiss button is the floating control, so the
    // stop-tracking menu only renders on the top button.
    return (
      this.showDismissNewStopTracking &&
      !(this.site.mobileView && this.args.position === "bottom")
    );
  }

  get dismissNewOptions() {
    const options = {
      dismissPosts: true,
      dismissTopics: true,
      untrack: false,
    };

    if (this.newListSubset === "topics") {
      options.dismissPosts = false;
    } else if (this.newListSubset === "replies") {
      options.dismissTopics = false;
    }

    return options;
  }

  @action
  dismissReadPosts() {
    this.modal.show(DismissReadModal, {
      model: {
        title: this.args.selectedTopics.length
          ? "topics.bulk.dismiss_read_with_selected"
          : "topics.bulk.dismiss_read",
        count: this.args.selectedTopics.length,
        dismissRead: this.args.dismissRead,
      },
    });
  }

  @action
  registerDMenu(api) {
    this.dMenu = api;
  }

  @action
  dismissNew(untrack = false) {
    this.args.resetNew({ ...this.dismissNewOptions, untrack });
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
