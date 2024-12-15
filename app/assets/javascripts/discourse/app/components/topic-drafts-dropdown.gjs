import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DiscourseURL from "discourse/lib/url";
import DMenu from "float-kit/components/d-menu";

export default class TopicDraftsDropdown extends Component {
  @service currentUser;
  @service composer;

  @tracked drafts = [];

  get showDraftMenu() {
    return this.args.showDraftsMenu;
  }

  get otherDraftsCount() {
    return this.args.otherDrafts > 0 ? `+${this.args.otherDrafts} other drafts` : "";
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
    this.drafts = draftsStream.content;
  }

  @action
  async resumeDraft(draft) {
    this.dMenu.close();

    if (draft.get("postUrl")) {
      DiscourseURL.routeTo(draft.get("postUrl"));
    } else {
      this.composer.open({
        draft,
        draftKey: draft.draft_key,
        draftSequence: draft.sequence,
        ...draft.data
      });
    }
  }

  <template>
    {{#if this.showDraftMenu}}
      <DMenu
        @identifier="topic-drafts-menu"
        @title="drafts.title"
        @icon="chevron-down"
        @onShow={{this.onShowMenu}}
        @onRegisterApi={{this.onRegisterApi}}
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
                <span>{{this.otherDraftsCount}}</span>
                <span>view all</span>
              </DButton>
            </dropdown.item>
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
