import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

const TopicTrigger = <template>
  <div class="control-group">
    <label class="control-label">
      {{i18n "discourse_automation.triggerables.topic.topic_id.label"}}
    </label>

    <div class="controls">
      <Input
        @value={{this.metadata.topic_id}}
        {{on
          "input"
          (action (mut this.metadata.topic_id) value="target.value")
        }}
      />
    </div>
  </div>
</template>;
export default TopicTrigger;
