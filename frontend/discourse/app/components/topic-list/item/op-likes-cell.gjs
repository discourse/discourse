import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { gt } from "discourse/truth-helpers";

const OpLikesCell = <template>
  <td class="num likes">
    {{#if (gt @topic.op_like_count 0)}}
      <a href={{@topic.summaryUrl}}>
        {{number @topic.op_like_count}}
        {{icon "heart"}}
      </a>
    {{/if}}
  </td>
</template>;

export default OpLikesCell;
