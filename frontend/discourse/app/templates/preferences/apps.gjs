import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import lazyHash from "discourse/helpers/lazy-hash";

export default <template>
  <UserApiKeys @model={{@model}} />

  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-preferences-apps"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>
</template>
