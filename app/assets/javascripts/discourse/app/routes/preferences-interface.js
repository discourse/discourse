import RestrictedUserRoute from "discourse/routes/restricted-user";
import { currentThemeId } from "discourse/lib/theme-selector";
import Session from "discourse/models/session";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    controller.setProperties({
      model: user,
      textSize: user.get("currentTextSize"),
      themeId: currentThemeId(),
      userColorSchemeId:
        parseInt(Session.currentProp("userColorSchemeId"), 10) || null,
      userDarkSchemeId:
        parseInt(Session.currentProp("userDarkSchemeId"), 10) || -1,
      makeThemeDefault:
        !user.get("user_option.theme_ids") ||
        currentThemeId() === user.get("user_option.theme_ids")[0],
      makeTextSizeDefault:
        user.get("currentTextSize") === user.get("user_option.text_size")
    });
  }
});
