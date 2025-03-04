import RouteTemplate from 'ember-route-template'
import getUrl from "discourse/helpers/get-url";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
export default RouteTemplate(<template><a class="tag-groups--back" href={{getUrl "/tags"}}>
  {{dIcon "chevron-left"}}
  <span>{{iN "tagging.groups.back_btn"}}</span>
</a>

<div class="container tag-groups-container">
  <h2>{{iN "tagging.groups.title"}}</h2>

  {{#if @controller.siteSettings.tagging_enabled}}
    {{#if @controller.model}}
      <div class="tag-groups-sidebar content-list">
        <ul>
          {{#each @controller.model as |tagGroup|}}
            <li>
              <LinkTo @route="tagGroups.edit" @model={{tagGroup}}>
                {{tagGroup.name}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>

        <DButton @action={{action "newTagGroup"}} @icon="plus" @label="tagging.groups.new" class="btn-default" />
      </div>
    {{/if}}

    {{outlet}}
  {{else}}
    <div class="tag-group-content">
      <div class="alert info">{{iN "tagging.groups.disabled"}}</div>
    </div>
  {{/if}}
</div></template>)