import { currentThemeId } from "discourse/lib/theme-selector";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesInterface extends RestrictedUserRoute {
  setupController(controller, user) {
    controller.setProperties({
      model: user,
      textSize: user.get("currentTextSize"),
      themeId: currentThemeId(),
      makeThemeDefault:
        !user.get("user_option.theme_ids") ||
        currentThemeId() === user.get("user_option.theme_ids")[0],
      makeTextSizeDefault:
        user.get("currentTextSize") === user.get("user_option.text_size"),
      enableDarkMode: user.get("user_option.dark_scheme_id") !== -1,
    });
  }
}
