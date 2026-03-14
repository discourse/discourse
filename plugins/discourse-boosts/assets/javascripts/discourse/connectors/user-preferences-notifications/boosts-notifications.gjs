import Component from "@glimmer/component";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

const BOOST_NOTIFICATIONS_LEVELS = [
  {
    name: i18n("discourse_boosts.user_option.boost_notifications_levels.all"),
    value: 0,
  },
  {
    name: i18n(
      "discourse_boosts.user_option.boost_notifications_levels.consolidated"
    ),
    value: 1,
  },
  {
    name: i18n(
      "discourse_boosts.user_option.boost_notifications_levels.disabled"
    ),
    value: 2,
  },
];

export default class BoostsNotifications extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.discourse_boosts_enabled;
  }

  onChange = (value) => {
    this.args.outletArgs.model.user_option.boost_notifications_level = value;
  };

  <template>
    <div
      class="user-preferences-notifications-outlet boosts-notifications"
      ...attributes
    >
      <div class="controls controls-dropdown">
        <label>{{i18n
            "discourse_boosts.user_option.boost_notifications_level"
          }}</label>
        <ComboBox
          @valueProperty="value"
          @content={{BOOST_NOTIFICATIONS_LEVELS}}
          @value={{@outletArgs.model.user_option.boost_notifications_level}}
          @onChange={{this.onChange}}
        />
      </div>
    </div>
  </template>
}
