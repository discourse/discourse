import Controller from "@ember/controller";
import { alias } from "@ember/object/computed";

export default class CakedayController extends Controller {
  @alias("siteSettings.cakeday_enabled") cakedayEnabled;
  @alias("siteSettings.cakeday_birthday_enabled") birthdayEnabled;
}
