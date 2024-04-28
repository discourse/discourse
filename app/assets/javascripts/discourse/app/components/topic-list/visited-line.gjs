import { eq } from "truth-helpers";
import i18n from "discourse-common/helpers/i18n";

const VisitedLine = <template>
  {{#if (eq @topic @lastVisitedTopic)}}
    <tr class="topic-list-item-separator">
      <td class="topic-list-data" colspan="6">
        <span>
          {{i18n "topics.new_messages_marker"}}
        </span>
      </td>
    </tr>
  {{/if}}
</template>;

export default VisitedLine;
