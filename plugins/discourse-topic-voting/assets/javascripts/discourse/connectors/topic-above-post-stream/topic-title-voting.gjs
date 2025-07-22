import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import routeAction from "discourse/helpers/route-action";
import VoteBox from "../../components/vote-box";

@tagName("div")
@classNames("topic-above-post-stream-outlet", "topic-title-voting")
export default class TopicTitleVoting extends Component {
  <template>
    {{#if this.model.can_vote}}
      {{#if this.model.postStream.loaded}}
        {{#if this.model.postStream.firstPostPresent}}
          <div class="voting title-voting">
            <VoteBox
              @topic={{this.model}}
              @showLogin={{routeAction "showLogin"}}
            />
          </div>
        {{/if}}
      {{/if}}
    {{/if}}
  </template>
}
