import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

const LoginRequired = <template>
  <h3>{{i18n "discourse_subscriptions.subscribe.unauthenticated"}}</h3>

  <DButton
    @label="log_in"
    @action={{routeAction "showLogin"}}
    @icon="user"
    class="btn btn-primary login-required subscriptions"
  />
</template>;

export default LoginRequired;
