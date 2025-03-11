import RouteTemplate from "ember-route-template";
import { htmlSafe } from "@ember/template";

export default RouteTemplate(
  <template>
    <div class="container">
      {{htmlSafe @controller.model}}
    </div>
  </template>
);
