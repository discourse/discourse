import Component from "@glimmer/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";

export default class SolvedNotifications extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.solved_enabled;
  }

  <template>
    <div class="control-group solved-notifications">
      <PreferenceCheckbox
        @labelKey="solved.notify_on_solved"
        @checked={{@outletArgs.model.user_option.notify_on_solved}}
        data-setting-name="user-notify-on-solved"
        class="pref-notify-on-solved"
      />
    </div>
  </template>
}
