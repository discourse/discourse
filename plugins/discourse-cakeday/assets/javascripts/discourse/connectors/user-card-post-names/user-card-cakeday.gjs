import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import {
  birthday,
  birthdayTitle,
  cakeday,
  cakedayTitle,
} from "discourse/plugins/discourse-cakeday/discourse/lib/cakeday";
import EmojiImages from "../../components/emoji-images";

@tagName("div")
@classNames("user-card-post-names-outlet", "user-card-cakeday")
export default class UserCardCakeday extends Component {
  init() {
    super.init(...arguments);
    const { user } = this;
    this.set("isCakeday", cakeday(user.cakedate));
    this.set("isBirthday", birthday(user.birthdate));
    this.set("cakedayTitle", cakedayTitle(user, this.currentUser));
    this.set("birthdayTitle", birthdayTitle(user, this.currentUser));
  }

  <template>
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
  </template>
}
