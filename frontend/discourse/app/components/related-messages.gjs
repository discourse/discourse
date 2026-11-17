import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import BasicTopicList from "discourse/components/basic-topic-list";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class RelatedMessages extends Component {
  @service currentUser;

  @cached
  get targetUser() {
    const { topic } = this.args;

    if (!topic || !topic.isPrivateMessage) {
      return;
    }

    if (
      topic.relatedMessages?.length >= 5 &&
      topic.details.allowed_groups.length === 0 &&
      topic.details.allowed_users.length === 2 &&
      topic.details.allowed_users.find(
        (u) => u.username === this.currentUser.username
      )
    ) {
      return topic.details.allowed_users.find(
        (u) => u.username !== this.currentUser.username
      );
    }
  }

  get searchLink() {
    return getURL(
      `/search?expanded=true&q=%40${this.targetUser.username}%20in%3Apersonal-direct`
    );
  }

  <template>
    <div
      aria-labelledby="related-messages-title"
      class="more-topics__list"
      id="related-messages"
      role="complementary"
    >
      <h3 class="more-topics__list-title" id="related-messages-title">
        {{i18n "related_messages.title"}}
      </h3>

      <div class="topics">
        <BasicTopicList
          @hideCategory={{true}}
          @listContext="related"
          @showPosters={{true}}
          @topics={{@topic.relatedMessages}}
        />
      </div>

      {{#if this.targetUser}}
        <h3 class="see-all-pms-message">
          {{trustHTML
            (i18n
              "related_messages.see_all"
              path=this.searchLink
              username=this.targetUser.username
            )
          }}
        </h3>
      {{/if}}
    </div>
  </template>
}
