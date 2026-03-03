import { currentThemeId } from "discourse/lib/theme-selector";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesInterface extends RestrictedUserRoute {
  setupController(controller, user) {
    controller.set("model", user);

    const userThemeIds = user.get("user_option.theme_ids");
    const themeId = controller.isViewingOwnProfile
      ? currentThemeId()
      : (userThemeIds?.[0] ?? currentThemeId());

    const textSize = controller.isViewingOwnProfile
      ? user.get("currentTextSize")
      : user.get("user_option.text_size");

    controller.setProperties({
      textSize,
      themeId,
      makeThemeDefault:
        !controller.isViewingOwnProfile ||
        !userThemeIds ||
        themeId === userThemeIds[0],
      makeTextSizeDefault:
        !controller.isViewingOwnProfile ||
        textSize === user.get("user_option.text_size"),
    });

    if (controller.isViewingOwnProfile) {
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
