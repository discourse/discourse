import BlockOutlet from "discourse/blocks/block-outlet";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default <template>
  <BlockOutlet @name="homepage-blocks" @outletArgs={{lazyHash model=@model}}>
    <:after as |hasBlocks|>
      <PluginOutlet
        @name="custom-homepage"
        @outletArgs={{lazyHash model=@model}}
      >
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
