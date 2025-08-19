import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
  @service currentUser;
  @service router;

  @action
  new() {
    this.router.transitionTo("groups.new");
  }

  @action
  loadMore() {
    this.args.groups && this.args.groups.loadMore();
  }

  get types() {
    const types = [];
    const typeFilters = this.args.groups.extras.type_filters;

    if (typeFilters) {
      typeFilters.forEach((type) =>
        types.push({ id: type, name: i18n(`groups.index.${type}_groups`) })
      );
    }

    return types;
  }

  <template>
    {{#if (or @groups.loadingMore @groups.canLoadMore)}}
      {{hideApplicationFooter}}
    {{/if}}

    {{bodyClass "groups-page"}}

    <PluginOutlet
      @name="before-groups-index-container"
      @connectorTagName="div"
    />

    <section class="container groups-index">
      <div class="groups-header">
        {{#if this.currentUser.can_create_group}}
          <DButton
            @action={{this.new}}
            @icon="plus"
            @label="admin.groups.new.title"
            class="btn-default groups-header-new pull-right"
          />
        {{/if}}

        <div class="groups-header-filters">
          <Input
            @value={{@filter}}
            placeholder={{i18n "groups.index.all"}}
            class="groups-header-filters-name no-blur"
            {{on "input" (withEventValue @onFilterChanged)}}
            @type="search"
            aria-description={{i18n "groups.index.search_results"}}
          />

          <ComboBox
            @value={{@type}}
            @content={{this.types}}
            @onChange={{@onTypeChanged}}
            @options={{hash clearable=true none="groups.index.filter"}}
            class="groups-header-filters-type"
          />
        </div>
      </div>

      {{#if @groups}}
        <LoadMore @action={{this.loadMore}}>
          <div class="container">
            <div class="groups-boxes">
              {{#each @groups as |group|}}
                <GroupCard @group={{group}} />
              {{/each}}
            </div>
          </div>
        </LoadMore>
        <ConditionalLoadingSpinner @condition={{@groups.loadingMore}} />
      {{else}}
        <p role="status">{{i18n "groups.index.empty"}}</p>
      {{/if}}
    </section>
  </template>
}
