import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  birthday,
  birthdayTitle,
  cakeday,
  cakedayTitle,
} from "discourse/plugins/discourse-cakeday/discourse/lib/cakeday";
import EmojiImages from "../../components/emoji-images.gjs";

export default class UserCardCakeday extends Component {
  @service currentUser;
  @service siteSettings;

  get isCakeday() {
    return cakeday(this.args.user.cakedate);
  }

  get isBirthday() {
    return birthday(this.args.user.birthdate);
  }

  get cakedayTitle() {
    return cakedayTitle(this.args.user, this.currentUser);
  }

  get birthdayTitle() {
    return birthdayTitle(this.args.user, this.currentUser);
  }

  <template>
    <div class="user-card-post-names-outlet user-card-cakeday" ...attributes>
      {{#if this.siteSettings.cakeday_birthday_enabled}}
        {{#if this.isBirthday}}
          <EmojiImages
            @list={{this.siteSettings.cakeday_birthday_emoji}}
            @title={{this.birthdayTitle}}
          />
        {{/if}}
      {{/if}}
      {{#if this.siteSettings.cakeday_enabled}}
        {{#if this.isCakeday}}
          <EmojiImages
            @list={{this.siteSettings.cakeday_emoji}}
            @title={{this.cakedayTitle}}
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
