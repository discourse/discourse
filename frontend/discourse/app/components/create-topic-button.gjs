import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DComboButton from "discourse/components/d-combo-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import DiscourseURL from "discourse/lib/url";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const DRAFTS_LIMIT = 4;

export default class CreateTopicButton extends Component {
  @service currentUser;
  @service composer;

  @tracked drafts = [];
  @tracked loading = false;
  dMenu;

  get btnTypeClass() {
    return this.args.btnTypeClass || "btn-default";
  }

  get label() {
    return this.args.label ?? "topic.create";
  }

  get btnId() {
    return this.args.btnId ?? "create-topic";
  }

  get otherDraftsCount() {
    return Math.max(this.currentUser.draft_count - DRAFTS_LIMIT, 0);
  }

  get otherDraftsText() {
    return this.otherDraftsCount > 0
      ? i18n("drafts.dropdown.other_drafts", {
          count: this.otherDraftsCount,
        })
      : "";
  }

  get showViewAll() {
    return this.currentUser.draft_count > DRAFTS_LIMIT;
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
    {{#if @canCreateTopic}}
      <DComboButton ...attributes as |Button Menu|>
        <Button
          @action={{@action}}
          @label={{this.label}}
          @icon="far-pen-to-square"
          id={{this.btnId}}
          class={{concatClass @btnClass this.btnTypeClass}}
        />

        {{#if @showDrafts}}
          <Menu
            @identifier="topic-drafts-menu"
            @title={{i18n "drafts.dropdown.title"}}
            @onShow={{this.onShowMenu}}
            @onRegisterApi={{this.onRegisterApi}}
            @modalForMobile={{true}}
            class={{concatClass "btn-small" this.btnTypeClass}}
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
          </Menu>
        {{/if}}
      </DComboButton>
    {{/if}}
  </template>
}
