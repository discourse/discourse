import Controller from "@ember/controller";
import { computed, set } from "@ember/object";

export default class CakedayController extends Controller {
  @computed("siteSettings.cakeday_enabled")
  get cakedayEnabled() {
    return this.siteSettings?.cakeday_enabled;
  }

  set cakedayEnabled(value) {
    set(this, "siteSettings.cakeday_enabled", value);
  }

  @computed("siteSettings.cakeday_birthday_enabled")
  get birthdayEnabled() {
    return this.siteSettings?.cakeday_birthday_enabled;
  }

  set birthdayEnabled(value) {
    set(this, "siteSettings.cakeday_birthday_enabled", value);
  }
}
