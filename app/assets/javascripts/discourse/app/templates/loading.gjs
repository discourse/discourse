import RouteTemplate from "ember-route-template";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import loadingSpinner from "discourse/helpers/loading-spinner";

export default RouteTemplate(
  <template>
    {{loadingSpinner}}
    {{hideApplicationFooter}}
  </template>
);
