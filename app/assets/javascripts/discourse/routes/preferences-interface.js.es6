import RestrictedUserRoute from "discourse/routes/restricted-user";
import { currentThemeKey } from 'discourse/lib/theme-selector';

export default RestrictedUserRoute.extend({
  setupController(controller, user) {
    controller.setProperties({
      model: user,
      selectedTheme: $.cookie('theme_key') || currentThemeKey()
    });
  }
});
