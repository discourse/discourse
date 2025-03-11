import RouteTemplate from "ember-route-template";
import bodyClass from "discourse/helpers/body-class";

export default RouteTemplate(
  <template>
    {{bodyClass "tags-page"}}
    {{outlet}}
  </template>
);
