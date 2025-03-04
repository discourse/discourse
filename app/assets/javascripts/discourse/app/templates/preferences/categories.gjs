import RouteTemplate from 'ember-route-template'
import Categories from "discourse/components/user-preferences/categories";
import SaveControls from "discourse/components/save-controls";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><Categories @canSee={{@controller.canSee}} @model={{@controller.model}} @selectedCategories={{@controller.selectedCategories}} @hideMutedTags={{@controller.hideMutedTags}} @save={{action "save"}} @siteSettings={{@controller.siteSettings}} />

{{#if @controller.canSave}}
  <SaveControls @model={{@controller.model}} @action={{action "save"}} @saved={{@controller.saved}} />
{{else}}
  {{iN "user.no_category_access"}}
{{/if}}</template>)