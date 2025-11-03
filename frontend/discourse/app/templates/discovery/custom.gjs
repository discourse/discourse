import BlockLayout from "discourse/components/block-layout";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet @name="custom-homepage">
    {{#if @controller.currentUser.admin}}
      <p class="alert alert-info">
        {{i18n "custom_homepage.admin_message"}}
      </p>
    {{/if}}
  </PluginOutlet>
  <BlockLayout @name="homepage-blocks" />
</template>
