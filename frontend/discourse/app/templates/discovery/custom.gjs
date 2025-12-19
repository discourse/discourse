import BlockOutlet from "discourse/components/block-outlet";
import PluginOutlet from "discourse/components/plugin-outlet";
import { hasConfig } from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

function hasBlocks() {
  return hasConfig("homepage-blocks");
}

export default <template>
  <BlockOutlet @name="homepage-blocks">
    {{yield}}
    <PluginOutlet @name="custom-homepage">
      {{#if @controller.currentUser.admin}}
        {{#unless (hasBlocks)}}
          <p class="alert alert-info">
            {{i18n "custom_homepage.admin_message"}}
          </p>
        {{/unless}}
      {{/if}}
    </PluginOutlet>
  </BlockOutlet>
</template>
