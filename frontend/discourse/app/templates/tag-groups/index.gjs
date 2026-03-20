import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="tag-group-content">
    <h3>
      {{#if @controller.model.content}}
        {{i18n "tagging.groups.about_heading"}}
      {{else}}
        {{i18n "tagging.groups.about_heading_empty"}}
      {{/if}}
    </h3>
    <section class="tag-groups-about">
      <p>{{i18n "tagging.groups.about_description"}}</p>
    </section>
    <section>
      {{#unless @controller.model.content}}
        <LinkTo @route="tagGroups.new" class="btn btn-primary">
          {{dIcon "plus"}}
          {{i18n "tagging.groups.new"}}
        </LinkTo>
      {{/unless}}
    </section>
  </div>
</template>
