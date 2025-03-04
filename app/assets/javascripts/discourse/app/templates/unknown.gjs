import RouteTemplate from 'ember-route-template';
import htmlSafe from "discourse/helpers/html-safe";
export default RouteTemplate(<template><div class="container">
  {{htmlSafe @controller.model}}
</div></template>);