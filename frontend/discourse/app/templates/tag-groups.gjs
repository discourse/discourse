import { LinkTo } from "@ember/routing";
import getUrl from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <a class="tag-groups--back" href={{getUrl "/tags"}}>
    {{dIcon "chevron-left"}}
    <span>{{i18n "tagging.groups.back_btn"}}</span>
  </a>

  <div class="container tag-groups-container">
    <h2>{{i18n "tagging.groups.title"}}</h2>

    {{#if @controller.siteSettings.tagging_enabled}}
      {{#if @controller.model.content}}
        <div class="tag-groups-sidebar content-list">
          <ul>
            {{#each @controller.model.content as |tagGroup|}}
              <li>
                <LinkTo @model={{tagGroup}} @route="tagGroups.edit">
                  {{tagGroup.name}}
                </LinkTo>
              </li>
            {{/each}}
          </ul>

          <DButton
            class="btn-default"
            @action={{@controller.newTagGroup}}
            @icon="plus"
            @label="tagging.groups.new"
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
