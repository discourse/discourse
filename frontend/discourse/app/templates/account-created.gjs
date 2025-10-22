import RouteTemplate from "ember-route-template";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";

export default RouteTemplate(
  <template>
    {{bodyClass "account-created-page"}}
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    <div class="account-created">
      {{outlet}}
    </div>
  </template>
);
