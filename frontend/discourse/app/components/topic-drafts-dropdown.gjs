import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
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
    let icon;

    if (item.draft_key.startsWith(NEW_TOPIC_KEY)) {
      icon = "layer-group";
    } else if (item.draft_key.startsWith(NEW_PRIVATE_MESSAGE_KEY)) {
      icon = "envelope";
    } else {
      icon = "reply";
    }

    return applyValueTransformer("draft-icon", icon, { draft: item });
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
      aria-label={{i18n "topic.create_group"}}
      class="topic-create-button__combo"
      ...attributes
      @btnTypeClass={{@btnTypeClass}}
      @hasMenu={{@showDrafts}}
      as |combo|
    >
      <combo.Button
        class={{@btnClasses}}
        id={{@btnId}}
        @action={{@action}}
        @ariaLabel={{@label}}
        @icon={{or @icon "far-pen-to-square"}}
        @label={{@label}}
      />

      <combo.Menu
        aria-label={{i18n "drafts.dropdown.title"}}
        class={{@draftMenuClasses}}
        @identifier="topic-drafts-menu"
        @modalForMobile={{true}}
        @onRegisterApi={{this.onRegisterApi}}
        @onShow={{this.onShowMenu}}
        @title={{i18n "drafts.dropdown.title"}}
      >
        <DDropdownMenu as |dropdown|>
          {{#each this.drafts as |draft|}}
            <dropdown.item class="topic-drafts-item">
              <DButton
                @action={{fn this.resumeDraft draft}}
                @icon={{this.draftIcon draft}}
                @translatedLabel={{or
                  draft.title
                  (i18n "drafts.dropdown.untitled")
                }}
              />
            </dropdown.item>
          {{/each}}

          {{#if this.showViewAll}}
            <dropdown.divider />

            <dropdown.item>
              <DButton
                class="btn-link view-all-drafts"
                @href={{getURL "/my/activity/drafts"}}
                @model={{this.currentUser}}
              >
                <span
                  data-other-drafts={{this.otherDraftsCount}}
                >{{this.otherDraftsText}}</span>
                <span>{{i18n "drafts.dropdown.view_all"}}</span>
              </DButton>
            </dropdown.item>
          {{/if}}
        </DDropdownMenu>
      </combo.Menu>
    </DComboButton>
  </template>
}
