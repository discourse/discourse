import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  birthday,
  birthdayTitle,
  cakeday,
  cakedayTitle,
} from "discourse/plugins/discourse-cakeday/discourse/lib/cakeday";
import EmojiImages from "../../components/emoji-images";

export default class UserCakeday extends Component {
  @service currentUser;
  @service siteSettings;

  get isCakeday() {
    return cakeday(this.args.model.cakedate);
  }

  get isBirthday() {
    return birthday(this.args.model.birthdate);
  }

  get cakedayTitle() {
    return cakedayTitle(this.args.model, this.currentUser);
  }

  get birthdayTitle() {
    return birthdayTitle(this.args.model, this.currentUser);
  }

  <template>
    <div class="user-post-names-outlet user-cakeday">
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
