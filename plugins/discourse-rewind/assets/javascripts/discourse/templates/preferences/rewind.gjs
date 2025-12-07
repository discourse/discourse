import { Input } from "@ember/component";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <label class="control-label">{{i18n "discourse_rewind.title"}}</label>

  <div
    class="control-group rewind-setting"
    data-setting-name="user_discourse_rewind_disabled"
  >
    <label class="controls">
      <Input
        id="user_discourse_rewind_disabled"
        @type="checkbox"
        @checked={{@controller.model.user_option.discourse_rewind_disabled}}
      />
      {{i18n "discourse_rewind.preferences.disable_rewind"}}
    </label>
  </div>

  <SaveControls
    @model={{@controller.model}}
    @action={{@controller.save}}
    @saved={{@controller.saved}}
  />
</template>
