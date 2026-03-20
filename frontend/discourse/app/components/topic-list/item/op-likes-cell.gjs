import { gt } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const OpLikesCell = <template>
  <td class="num likes">
    {{#if (gt @topic.op_like_count 0)}}
      <a href={{@topic.summaryUrl}}>
        {{dNumber @topic.op_like_count}}
        {{dIcon "heart"}}
      </a>
    {{/if}}
  </td>
</template>;

export default OpLikesCell;
