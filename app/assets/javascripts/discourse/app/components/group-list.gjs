import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import GroupCard from "discourse/components/group-card";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class GroupList extends Component {
  <template>
    {{#if (or @controller.loading @controller.groups.canLoadMore)}}
      {{hideApplicationFooter}}
    {{/if}}

    {{bodyClass "groups-page"}}

    <PluginOutlet
      @name="before-groups-index-container"
      @connectorTagName="div"
    />

    <section class="container groups-index">
      <div class="groups-header">
        {{#if @controller.currentUser.can_create_group}}
          <DButton
            @action={{@controller.new}}
            @icon="plus"
            @label="admin.groups.new.title"
            class="btn-default groups-header-new pull-right"
          />
        {{/if}}

        <div class="groups-header-filters">
          <Input
            @value={{readonly @controller.filter}}
            placeholder={{i18n "groups.index.all"}}
            class="groups-header-filters-name no-blur"
            {{on "input" (withEventValue @controller.onFilterChanged)}}
            @type="search"
            aria-description={{i18n "groups.index.search_results"}}
          />

          <ComboBox
            @value={{@controller.type}}
            @content={{@controller.types}}
            @onChange={{fn (mut @controller.type)}}
            @options={{hash clearable=true none="groups.index.filter"}}
            class="groups-header-filters-type"
          />
        </div>
      </div>

      {{#if @controller.groups}}
        <LoadMore
          @selector=".groups-boxes .group-box"
          @action={{@controller.loadMore}}
        >
          <div class="container">
            <div class="groups-boxes">
              {{#each @controller.groups as |group|}}
                <GroupCard @group={{group}} />
              {{/each}}
            </div>
          </div>
        </LoadMore>
        <ConditionalLoadingSpinner
          @condition={{@controller.groups.loadingMore}}
        />
      {{else}}
        <p role="status">{{i18n "groups.index.empty"}}</p>
      {{/if}}
    </section>
  </template>
}
