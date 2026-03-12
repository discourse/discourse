import { gt } from "discourse/truth-helpers";
import icon from "discourse/ui-kit/helpers/d-icon";
import number from "discourse/ui-kit/helpers/d-number";

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
