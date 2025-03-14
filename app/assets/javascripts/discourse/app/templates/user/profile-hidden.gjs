import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <p class="user-profile-hidden">{{i18n "user.profile_hidden"}}</p>
  </template>
);
