import { i18n } from "discourse-i18n";
import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <div class="container">
    <PluginOutlet @name="above-subscriptions-subscribe-title" />

    <div class="title-wrapper">
      <h1>
        {{i18n "discourse_subscriptions.subscribe.title"}}
      </h1>
    </div>

    <hr />

    {{outlet}}
  </div>
</template>
