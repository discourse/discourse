import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

const TopicTrigger = <template>
  <div class="control-group">
    <label class="control-label">
      {{i18n "discourse_automation.triggerables.topic.topic_id.label"}}
    </label>

    <div class="controls">
      <Input
        @value={{this.metadata.topic_id}}
        {{on "input" (withEventValue (fn (mut this.metadata.topic_id)))}}
      />
    </div>
  </div>
</template>;

export default TopicTrigger;
