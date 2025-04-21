import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigLogoAndFontsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.logo_and_fonts.title");
  }
}
