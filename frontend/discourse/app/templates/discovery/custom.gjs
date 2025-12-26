import BlockOutlet from "discourse/components/block-outlet";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

export default <template>
  <BlockOutlet @name="homepage-blocks">
    <:after as |hasBlocks|>
      <PluginOutlet @name="custom-homepage">
        {{#if @controller.currentUser.admin}}
          {{#unless hasBlocks}}
            <p class="alert alert-info">
              {{i18n "custom_homepage.admin_message"}}
            </p>
          {{/unless}}
        {{/if}}
      </PluginOutlet>
    </:after>
  </BlockOutlet>
</template>
