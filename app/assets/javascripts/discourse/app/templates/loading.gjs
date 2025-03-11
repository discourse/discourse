import RouteTemplate from 'ember-route-template'
import loadingSpinner from "discourse/helpers/loading-spinner";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
export default RouteTemplate(<template>{{loadingSpinner}}
{{hideApplicationFooter}}</template>)