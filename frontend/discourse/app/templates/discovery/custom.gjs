import BlockFrame from "discourse/components/block-frame";
import PluginOutlet from "discourse/components/plugin-outlet";
import { blockConfigs } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

function hasBlocks() {
  return blockConfigs.has("homepage");
}

export default <template>
  <BlockFrame @name="homepage" />

  <PluginOutlet @name="custom-homepage">
    {{#if @controller.currentUser.admin}}
      {{#unless (hasBlocks)}}
        <p class="alert alert-info">
          {{i18n "custom_homepage.admin_message"}}
        </p>
      {{/unless}}
    {{/if}}
  </PluginOutlet>
</template>
