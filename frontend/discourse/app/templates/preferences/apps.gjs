import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import UserMcpAuthorizations from "discourse/components/user-preferences/user-mcp-authorizations";
import lazyHash from "discourse/helpers/lazy-hash";

export default <template>
  <UserApiKeys @model={{@model}} />
  <UserMcpAuthorizations @model={{@model}} />

  <span>
    <PluginOutlet
      @name="user-preferences-apps"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>
</template>
