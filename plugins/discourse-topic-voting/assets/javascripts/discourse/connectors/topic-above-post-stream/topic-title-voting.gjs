/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import routeAction from "discourse/helpers/route-action";
import VoteBox from "../../components/vote-box";

@tagName("")
export default class TopicTitleVoting extends Component {
  <template>
    <div
      class="topic-above-post-stream-outlet topic-title-voting"
      ...attributes
    >
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
    </div>
  </template>
}
