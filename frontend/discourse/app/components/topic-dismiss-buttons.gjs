import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DComboButton from "discourse/components/d-combo-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DismissReadModal from "discourse/components/modal/dismiss-read";
import { i18n } from "discourse-i18n";

export default class TopicDismissButtons extends Component {
  @service currentUser;
  @service modal;

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
    if (this.currentUser?.new_new_view_enabled) {
      switch (this.newListSubset) {
        case "topics":
          return i18n("topics.bulk.dismiss_new_topics");
        case "replies":
          return i18n("topics.bulk.dismiss_new_replies");
        default:
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
            @action={{this.dismissReadPosts}}
            @translatedLabel={{this.dismissLabel}}
            @title="topics.bulk.dismiss_tooltip"
            id="dismiss-topics-{{@position}}"
            class="btn-default dismiss-read"
          />
        {{~/if~}}
        {{~#if @showResetNew~}}
          {{#if @showNewDismissCombo}}
            <DComboButton
              class="--has-menu topic-dismiss-buttons__combo"
              as |combo|
            >
              <combo.Button
                @action={{this.dismissNew}}
                @translatedLabel={{this.dismissNewLabel}}
                id="dismiss-new-{{@position}}"
                class="btn-default dismiss-read topic-dismiss-buttons__button"
              />

              {{#if @showDismissNewStopTracking}}
                <combo.Menu
                  @identifier="dismiss-new-menu"
                  @onRegisterApi={{this.registerDMenu}}
                  @modalForMobile={{true}}
                  @placement="bottom-end"
                  aria-label={{i18n "topics.bulk.dismiss_new_menu"}}
                  id="dismiss-new-menu-{{@position}}"
                  class="btn-default dismiss-read topic-dismiss-buttons__menu"
                >
                  <DropdownMenu as |dropdown|>
                    <dropdown.item class="topic-dismiss-buttons__menu-item">
                      <DButton
                        @action={{this.dismissNewAndStopTracking}}
                        @translatedLabel={{i18n
                          "topics.bulk.dismiss_and_stop_tracking"
                        }}
                        class="btn-secondary dismiss-new-stop-tracking"
                      />
                    </dropdown.item>
                  </DropdownMenu>
                </combo.Menu>
              {{/if}}
            </DComboButton>
          {{else}}
            <DButton
              @action={{@resetNew}}
              @translatedLabel={{this.dismissNewLabel}}
              @icon="check"
              id="dismiss-new-{{@position}}"
              class="btn-default dismiss-read"
            />
          {{/if}}
        {{~/if~}}
      </div>
    {{~/if~}}
  </template>
}
