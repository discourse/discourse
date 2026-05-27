import Component from "@glimmer/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

export default class SolvedNotifications extends Component {
  static shouldRender(_args, { siteSettings, site }) {
    if (!siteSettings.solved_enabled) {
      return false;
    }

    if (siteSettings.allow_solved_on_all_topics) {
      return true;
    }

    const solvedCategories = site.categories?.some(
      (c) => c.custom_fields?.enable_accepted_answers === "true"
    );

    return solvedCategories || siteSettings.enable_solved_tags?.length > 0;
  }

  <template>
    <div class="control-group solved-notifications">
      <label class="control-label">{{i18n "solved.title"}}</label>
      <PreferenceCheckbox
        @labelKey="solved.notify_on_solved"
        @checked={{@outletArgs.model.user_option.notify_on_solved}}
        data-setting-name="user-notify-on-solved"
        class="pref-notify-on-solved"
      />
    </div>
  </template>
}
