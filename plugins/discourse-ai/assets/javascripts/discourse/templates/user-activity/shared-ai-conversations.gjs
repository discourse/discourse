import { array } from "@ember/helper";
import SharedConversationsList from "../../components/shared-conversations-list";

export default <template>
  {{#each (array @model) key="@identity" as |data|}}
    <SharedConversationsList @data={{data}} />
  {{/each}}
</template>
