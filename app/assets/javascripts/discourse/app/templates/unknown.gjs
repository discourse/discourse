import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";

export default RouteTemplate(
  <template>
    <div class="container">
      {{htmlSafe @controller.model}}
    </div>
  </template>
);
