import BlockLayout from "discourse/components/block-layout";
import PluginOutlet from "discourse/components/plugin-outlet";
import { blockConfigs } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

function hasBlocks() {
  return blockConfigs.has("homepage-blocks");
}

export default <template>
  {{#if (hasBlocks)}}
    <BlockLayout @name="homepage-blocks" />
  {{else}}

    <PluginOutlet @name="custom-homepage">
      {{#if @controller.currentUser.admin}}
        <p class="alert alert-info">
          {{i18n "custom_homepage.admin_message"}}
        </p>
      {{/if}}
    </PluginOutlet>
  {{/if}}
</template>
