import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseCaptchaTestRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-captcha/test.json");
  }
}
