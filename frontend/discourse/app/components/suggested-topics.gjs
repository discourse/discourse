import Component from "@glimmer/component";
import { service } from "@ember/service";
import BasicTopicList from "discourse/components/basic-topic-list";
import UserTip from "discourse/components/user-tip";
import { i18n } from "discourse-i18n";

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
      aria-labelledby="suggested-topics-title"
      class="more-topics__list"
      id="suggested-topics"
      role="complementary"
    >
      <UserTip
        @contentText={{i18n "user_tips.suggested_topics.content"}}
        @id="suggested_topics"
        @placement="top-start"
        @priority={{700}}
        @titleText={{i18n "user_tips.suggested_topics.title"}}
      />

      <h3 class="more-topics__list-title" id="suggested-topics-title">
        {{this.suggestedTitle}}
      </h3>

      <div class="topics">
        {{#if @topic.isPrivateMessage}}
          <BasicTopicList
            @hideCategory={{true}}
            @listContext="suggested"
            @showPosters={{true}}
            @topics={{@topic.suggestedTopics}}
          />
        {{else}}
          <BasicTopicList
            @listContext="suggested"
            @topics={{@topic.suggestedTopics}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
