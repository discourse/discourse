import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import User from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import IgnoredUserListItem from "./ignored-user-list-item";
import ModalService from "discourse/services/modal";

export default class IgnoredUserList extends Component {
  @service(() => ModalService) modal;

  @action
  async removeIgnoredUser(item) {
    removeValueFromArray(this.args.items, item);

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
    this.modal.show(() => import("./modal/ignore-duration-with-username"), {
      model: {
        actingUser: this.args.model,
        ignoredUsername: null,
        onUserIgnored: (username) => {
          addUniqueValueToArray(this.args.items, username);
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
          class="btn-default"
          @action={{this.newIgnoredUser}}
          @icon="plus"
          @label="user.user_notifications.add_ignored_user"
        />
      </div>
    </div>
  </template>
}
