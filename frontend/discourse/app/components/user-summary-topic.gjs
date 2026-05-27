/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

@tagName("")
export default class UserSummaryTopic extends Component {
  <template>
    <li ...attributes>
      <PluginOutlet
        @name="user-summary-topic-wrapper"
        @outletArgs={{lazyHash
          topic=@topic
          url=@url
          createdAt=@createdAt
          likes=@likes
        }}
      >
        <span class="topic-info">
          {{dFormatDate @createdAt format="tiny" noTitle="true"}}
          {{#if @likes}}
            &middot;
            {{dIcon "heart"}}&nbsp;<span class="like-count">{{dNumber
                @likes
              }}</span>
          {{/if}}
        </span>
        <br />
        <a href={{@url}}>{{trustHTML @topic.fancyTitle}}</a>
      </PluginOutlet>
    </li>
  </template>
}
