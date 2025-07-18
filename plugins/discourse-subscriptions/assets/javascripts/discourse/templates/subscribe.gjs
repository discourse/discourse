import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="container">
      <div class="title-wrapper">
        <h1>
          {{i18n "discourse_subscriptions.subscribe.title"}}
        </h1>
      </div>

      <hr />

      {{outlet}}
    </div>
  </template>
);
