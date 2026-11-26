import { currentThemeId } from "discourse/lib/theme-selector";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesInterface extends RestrictedUserRoute {
  setupController(controller, user) {
    controller.set("model", user);

    const userThemeIds = user.get("user_option.theme_ids");
    const themeId = user.isCurrent
      ? currentThemeId()
      : (userThemeIds?.[0] ?? currentThemeId());

    const textSize = user.isCurrent
      ? user.get("currentTextSize")
      : user.get("user_option.text_size");

    controller.setProperties({
      textSize,
      themeId,
      currentThemeId: themeId,
      makeThemeDefault:
        !user.isCurrent || !userThemeIds || themeId === userThemeIds[0],
      makeTextSizeDefault:
        !user.isCurrent || textSize === user.get("user_option.text_size"),
    });

    if (user.isCurrent) {
      controller.setProperties({
        selectedColorSchemeId: controller.getSelectedColorSchemeId(),
        selectedDarkColorSchemeId: controller.session.userDarkSchemeId,
      });
    } else {
      controller.setProperties({
        selectedColorSchemeId: user.get("user_option.color_scheme_id"),
        selectedDarkColorSchemeId: user.get("user_option.dark_scheme_id"),
      });
    }
  }
}
