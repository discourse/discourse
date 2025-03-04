import RouteTemplate from 'ember-route-template'
import iN from "discourse/helpers/i18n";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/helpers/d-icon";
export default RouteTemplate(<template><div class="tag-group-content">
  <h3>
    {{#if @controller.model}}
      {{iN "tagging.groups.about_heading"}}
    {{else}}
      {{iN "tagging.groups.about_heading_empty"}}
    {{/if}}
  </h3>
  <section class="tag-groups-about">
    <p>{{iN "tagging.groups.about_description"}}</p>
  </section>
  <section>
    {{#unless @controller.model}}
      <LinkTo @route="tagGroups.new" class="btn btn-primary">
        {{dIcon "plus"}}
        {{iN "tagging.groups.new"}}
      </LinkTo>
    {{/unless}}
  </section>
</div></template>)