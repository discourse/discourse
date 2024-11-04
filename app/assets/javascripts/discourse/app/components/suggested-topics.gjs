import Component from "@glimmer/component";
import { service } from "@ember/service";
import BasicTopicList from "discourse/components/basic-topic-list";
import UserTip from "discourse/components/user-tip";
import i18n from "discourse-common/helpers/i18n";

export default class SuggestedTopics extends Component {
  @service currentUser;

  get suggestedTitle() {
    const href = this.currentUser?.pmPath(this.args.topic);
    if (href && this.args.topic.isPrivateMessage) {
      return i18n("suggested_topics.pm_title");
    } else {
      return i18n("suggested_topics.title");
    }
  }

  <template>
    <div
      role="complementary"
      aria-labelledby="suggested-topics-title"
      id="suggested-topics"
      class="more-topics__list"
    >
      <UserTip
        @id="suggested_topics"
        @titleText={{i18n "user_tips.suggested_topics.title"}}
        @contentText={{i18n "user_tips.suggested_topics.content"}}
        @placement="top-start"
        @priority={{700}}
      />

      <h3 id="suggested-topics-title" class="more-topics__list-title">
        {{this.suggestedTitle}}
      </h3>

      <div class="topics">
        {{#if @topic.isPrivateMessage}}
          <BasicTopicList
            @topics={{@topic.suggestedTopics}}
            @hideCategory={{true}}
            @showPosters={{true}}
          />
        {{else}}
          <BasicTopicList @topics={{@topic.suggestedTopics}} />
        {{/if}}
      </div>
    </div>
  </template>
}
