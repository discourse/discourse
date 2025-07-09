import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";

export default RouteTemplate(
  <template>
    <PluginOutlet @name="login-required">
      {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
      {{hideApplicationSidebar}}
      {{bodyClass "login-page"}}
      {{bodyClass "static-login"}}

      <section class="container">
        <div class="contents clearfix body-page">
          <div class="login-welcome">
            <PluginOutlet
              @name="above-login"
              @outletArgs={{lazyHash model=@controller.model}}
            />
            <PluginOutlet @name="above-static" />

            <div class="login-content">
              {{htmlSafe @controller.model.html}}
            </div>

            <PluginOutlet @name="below-static" />
            <PluginOutlet
              @name="below-login"
              @outletArgs={{lazyHash model=@controller.model}}
            />

            <div class="body-page-button-container">
              {{#if @controller.application.canSignUp}}
                <DButton
                  @action={{routeAction "showCreateAccount"}}
                  @label="sign_up"
                  class="btn-primary sign-up-button"
                />
              {{/if}}

              <DButton
                @action={{routeAction "showLogin"}}
                @icon="user"
                @label="log_in"
                class="btn-primary login-button"
              />
            </div>

            <PluginOutlet
              @name="below-login-buttons"
              @outletArgs={{lazyHash model=@controller.model}}
            />
          </div>
        </div>
      </section>
    </PluginOutlet>
  </template>
);
