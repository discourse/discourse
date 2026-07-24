import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { getTopicStatusBadge } from "../../lib/topic-status-badge";

export default class TopicStatusColumn extends Component {
  get badge() {
    return getTopicStatusBadge(this.args.topic);
  }

  <template>
    {{#if this.badge}}
      <span class="topic-status-card {{this.badge.className}}">{{dIcon
          this.badge.icon
        }}<p class="topic-status-card__name">{{i18n this.badge.text}}</p></span>
    {{/if}}
  </template>
}
