import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import getUrl from "discourse/helpers/get-url";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <a class="tag-groups--back" href={{getUrl "/tags"}}>
      {{icon "chevron-left"}}
      <span>{{i18n "tagging.groups.back_btn"}}</span>
    </a>

    <div class="container tag-groups-container">
      <h2>{{i18n "tagging.groups.title"}}</h2>

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

            <DButton
              @action={{@controller.newTagGroup}}
              @icon="plus"
              @label="tagging.groups.new"
              class="btn-default"
            />
          </div>
        {{/if}}

        {{outlet}}
      {{else}}
        <div class="tag-group-content">
          <div class="alert info">{{i18n "tagging.groups.disabled"}}</div>
        </div>
      {{/if}}
    </div>
  </template>
);
