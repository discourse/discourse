import { gt } from "truth-helpers";
import number from "discourse/helpers/number";
import icon from "discourse-common/helpers/d-icon";

const LikesCell = <template>
  {{#if @showLikes}}
    <td class="num likes topic-list-data">
      {{#if (gt @topic.like_count 0)}}
        <a href={{@topic.summaryUrl}}>
          {{number @topic.like_count}}
          {{icon "heart"}}
        </a>
      {{/if}}
    </td>
  {{/if}}
</template>;

export default LikesCell;
