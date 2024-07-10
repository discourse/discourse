import { htmlSafe } from "@ember/template";
import formatDate from "discourse/helpers/format-date";
import number from "discourse/helpers/number";
import icon from "discourse-common/helpers/d-icon";

const UserSummaryTopic = <template>
  <li>
    <span class="topic-info">
      {{formatDate @createdAt format="tiny" noTitle="true"}}
      {{#if @likes}}
        &middot;
        {{icon "heart"}}&nbsp;<span class="like-count">{{number @likes}}</span>
      {{/if}}
    </span>
    <br />
    <a href={{@url}}>{{htmlSafe @topic.fancyTitle}}</a>
  </li>
</template>;

export default UserSummaryTopic;
