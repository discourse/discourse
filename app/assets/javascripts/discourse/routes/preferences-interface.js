import RestrictedUserRoute from "discourse/routes/restricted-user";
import { currentThemeId } from "discourse/lib/theme-selector";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    controller.setProperties({
      model: user,
      textSize: user.get("currentTextSize"),
      themeId: currentThemeId(),
      makeThemeDefault:
        !user.get("user_option.theme_ids") ||
        currentThemeId() === user.get("user_option.theme_ids")[0],
      makeTextSizeDefault:
        user.get("currentTextSize") === user.get("user_option.text_size")
    });
  }
});
