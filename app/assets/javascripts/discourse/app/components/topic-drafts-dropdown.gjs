import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class TopicDraftsDropdown extends Component {
  @service currentUser;
  @service composer;

  @tracked drafts = [];

  get shouldDisplay() {
    return this.args.showDraftsMenu;
  }

  get otherDraftsText() {
    return this.args.otherDraftsCount > 0
      ? i18n("drafts.dropdown.other_drafts", {
          count: this.args.otherDraftsCount,
        })
      : "";
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async onShowMenu() {
    const draftsStream = this.currentUser.get("userDraftsStream");
    draftsStream.reset();

    await draftsStream.findItems(this.site);
    this.drafts = draftsStream.content.slice(0, this.args.draftLimit);
  }

  @action
  async resumeDraft(draft) {
    await this.dMenu.close();

    if (draft.get("postUrl")) {
      DiscourseURL.routeTo(draft.get("postUrl"));
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
    {{#if this.shouldDisplay}}
      <DMenu
        @identifier="topic-drafts-menu"
        @title={{i18n "drafts.dropdown.title"}}
        @icon="chevron-down"
        @onShow={{this.onShowMenu}}
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        class="btn-small"
      >
        <:content>
          <DropdownMenu as |dropdown|>
            {{#each this.drafts as |draft|}}
              <dropdown.item class="topic-drafts-item">
                <DButton
                  @action={{fn this.resumeDraft draft}}
                  @icon={{if draft.topic_id "reply" "layer-group"}}
                  @translatedLabel={{draft.title}}
                  class="btn-secondary"
                />
              </dropdown.item>
            {{/each}}

            <dropdown.divider />

            <dropdown.item>
              <DButton
                @href="/my/activity/drafts"
                @model={{this.currentUser}}
                class="btn-link view-all-drafts"
              >
                <span
                  data-other-drafts={{@otherDraftsCount}}
                >{{this.otherDraftsText}}</span>
                <span>{{i18n "drafts.dropdown.view_all"}}</span>
              </DButton>
            </dropdown.item>
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
