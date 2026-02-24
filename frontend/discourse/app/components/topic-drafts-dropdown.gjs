import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DComboButton from "discourse/components/d-combo-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DiscourseURL from "discourse/lib/url";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const DRAFTS_LIMIT = 4;

export default class TopicDraftsDropdown extends Component {
  @service currentUser;
  @service composer;

  @tracked drafts = [];
  @tracked loading = false;
  dMenu;

  get draftCount() {
    return this.currentUser.draft_count;
  }

  get otherDraftsCount() {
    return this.draftCount > DRAFTS_LIMIT ? this.draftCount - DRAFTS_LIMIT : 0;
  }

  get otherDraftsText() {
    return this.otherDraftsCount > 0
      ? i18n("drafts.dropdown.other_drafts", {
          count: this.otherDraftsCount,
        })
      : "";
  }

  get showViewAll() {
    return this.draftCount > DRAFTS_LIMIT;
  }

  draftIcon(item) {
    if (item.draft_key.startsWith(NEW_TOPIC_KEY)) {
      return "layer-group";
    } else if (item.draft_key.startsWith(NEW_PRIVATE_MESSAGE_KEY)) {
      return "envelope";
    } else {
      return "reply";
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async onShowMenu() {
    if (this.loading) {
      return;
    }

    this.loading = true;

    try {
      const draftsStream = this.currentUser.userDraftsStream;
      draftsStream.reset();

      await draftsStream.findItems(this.site);
      this.drafts = draftsStream.content.slice(0, DRAFTS_LIMIT);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to fetch drafts with error:", error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async resumeDraft(draft) {
    await this.dMenu.close();

    if (draft.postUrl) {
      DiscourseURL.routeTo(draft.postUrl);
    } else {
      this.composer.open({
        draft,
        draftKey: draft.draft_key,
        draftSequence: draft.sequence,
        ...draft.data,
      });
    }
  }

  <template>
    <DComboButton
      class={{if @showDrafts "--has-menu"}}
      aria-label={{i18n "topic.create_group"}}
      ...attributes
      as |combo|
    >
      <combo.Button
        @action={{@action}}
        @label={{@label}}
        @icon="far-pen-to-square"
        id={{@btnId}}
        class={{@btnClasses}}
      />

      {{#if @showDrafts}}
        <combo.Menu
          @identifier="topic-drafts-menu"
          @title={{i18n "drafts.dropdown.title"}}
          @onShow={{this.onShowMenu}}
          @onRegisterApi={{this.onRegisterApi}}
          @modalForMobile={{true}}
          aria-label={{i18n "drafts.dropdown.title"}}
          class={{@btnTypeClass}}
        >
          <DropdownMenu as |dropdown|>
            {{#each this.drafts as |draft|}}
              <dropdown.item class="topic-drafts-item">
                <DButton
                  @action={{fn this.resumeDraft draft}}
                  @icon={{this.draftIcon draft}}
                  @translatedLabel={{or
                    draft.title
                    (i18n "drafts.dropdown.untitled")
                  }}
                  class="btn-secondary"
                />
              </dropdown.item>
            {{/each}}

            {{#if this.showViewAll}}
              <dropdown.divider />

              <dropdown.item>
                <DButton
                  @href="/my/activity/drafts"
                  @model={{this.currentUser}}
                  class="btn-link view-all-drafts"
                >
                  <span
                    data-other-drafts={{this.otherDraftsCount}}
                  >{{this.otherDraftsText}}</span>
                  <span>{{i18n "drafts.dropdown.view_all"}}</span>
                </DButton>
              </dropdown.item>
            {{/if}}
          </DropdownMenu>
        </combo.Menu>
      {{/if}}
    </DComboButton>
  </template>
}
