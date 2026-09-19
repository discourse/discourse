import { gt } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const LikesCell = <template>
  <td class="num likes topic-list-data">
    {{#if (gt @topic.like_count 0)}}
      <a href={{@topic.summaryUrl}}>
        {{dNumber @topic.like_count}}
        {{dIcon "heart"}}
      </a>
    {{/if}}
  </td>
</template>;

export default LikesCell;
