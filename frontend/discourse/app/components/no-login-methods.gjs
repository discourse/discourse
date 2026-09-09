import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class NoLoginMethods extends Component {
  get adminLoginPath() {
    return getURL("/u/admin-login");
  }

  <template>
    <div class="login-welcome-header no-login-methods-configured">
      <h1 class="login-title">{{i18n "login.no_login_methods.title"}}</h1>
      <img />
      <p class="login-subheader">
        {{trustHTML
          (i18n
            "login.no_login_methods.description"
            (hash adminLoginPath=this.adminLoginPath)
          )
        }}
      </p>
    </div>
  </template>
}
