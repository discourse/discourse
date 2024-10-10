import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import BasicTopicList from "discourse/components/basic-topic-list";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";

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
      role="complementary"
      aria-labelledby="related-messages-title"
      id="related-messages"
      class="more-topics__list"
    >
      <h3 id="related-messages-title" class="more-topics__list-title">
        {{i18n "related_messages.title"}}
      </h3>

      <div class="topics">
        <BasicTopicList
          @topics={{@topic.relatedMessages}}
          @hideCategory={{true}}
          @showPosters={{true}}
        />
      </div>

      {{#if this.targetUser}}
        <h3 class="see-all-pms-message">
          {{htmlSafe
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
