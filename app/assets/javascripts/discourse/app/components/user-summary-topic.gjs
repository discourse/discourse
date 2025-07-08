import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import number from "discourse/helpers/number";

@tagName("li")
export default class UserSummaryTopic extends Component {
  <template>
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
        {{formatDate @createdAt format="tiny" noTitle="true"}}
        {{#if @likes}}
          &middot;
          {{icon "heart"}}&nbsp;<span class="like-count">{{number
              @likes
            }}</span>
        {{/if}}
      </span>
      <br />
      <a href={{@url}}>{{htmlSafe @topic.fancyTitle}}</a>
    </PluginOutlet>
  </template>
}
