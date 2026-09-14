import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const LoginRequired = <template>
  <h3>{{i18n "discourse_subscriptions.subscribe.unauthenticated"}}</h3>

  <DButton
    class="btn btn-primary login-required subscriptions"
    @action={{routeAction "showLogin"}}
    @icon="user"
    @label="log_in"
  />
</template>;

export default LoginRequired;
