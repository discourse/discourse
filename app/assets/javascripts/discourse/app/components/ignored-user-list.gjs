import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";
import IgnoredUserListItem from "./ignored-user-list-item";
import IgnoreDurationModal from "./modal/ignore-duration-with-username";

export default class IgnoredUserList extends Component {
  @service modal;

  @action
  async removeIgnoredUser(item) {
    this.args.items.removeObject(item);

    try {
      const user = await User.findByUsername(item);
      await user.updateNotificationLevel({
        level: "normal",
        actingUser: this.args.model,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  newIgnoredUser() {
    this.modal.show(IgnoreDurationModal, {
      model: {
        actingUser: this.args.model,
        ignoredUsername: null,
        onUserIgnored: (username) => {
          this.args.items.addObject(username);
        },
      },
    });
  }

  <template>
    <div>
      <div class="ignored-list">
        {{#each @items as |item|}}
          <IgnoredUserListItem
            @item={{item}}
            @onRemoveIgnoredUser={{this.removeIgnoredUser}}
          />
        {{else}}
          {{i18n "user.user_notifications.ignore_no_users"}}
        {{/each}}
      </div>
      <div class="instructions">{{i18n "user.ignored_users_instructions"}}</div>
      <div>
        <DButton
          @action={{this.newIgnoredUser}}
          @icon="plus"
          @label="user.user_notifications.add_ignored_user"
          class="btn-default"
        />
      </div>
    </div>
  </template>
}
