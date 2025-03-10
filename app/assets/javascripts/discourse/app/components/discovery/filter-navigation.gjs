import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import Tags from "discourse/components/discovery/filter-navigation/tags";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";
import and from "truth-helpers/helpers/and";

export default class DiscoveryFilterNavigation extends Component {
  @service site;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @resettableTracked newQueryString = this.args.queryString;

  availableSorts = [
    "likes",
    "op_likes",
    "views",
    "posts",
    "activity",
    "posters",
    "category",
    "created",
  ];

  filterPlaceholder = i18n("form_templates.filter_placeholder");

  @cached
  get formData() {
    return {
      query: "",
      tags: [{ name: "rest-api" }],
    };
  }

  @bind
  updateQueryString(string) {
    this.newQueryString = string;
  }

  @action
  formatDate(set, moment) {
    set(moment.format("YYYY-MM-DD"));
  }

  @action
  updateFilter(data) {
    let queryParts = [];

    // if (data.categories?.length) {
    //   const categoryNames = data.categories
    //     .map((category) => {
    //       // need to account for category names with spaces
    //       return category.name.replace(/ /g, "-");
    //     })
    //     .join(",");
    //   queryParts.push(`categories:${categoryNames}`);
    // }

    if (data.tags?.length) {
      const tagNames = data.tags.map((tag) => tag.name).join(",");
      queryParts.push(`tags:${tagNames}`);
    }

    // if (data.created_by?.length) {
    //   const createdByUsernames = data.created_by.join(",");
    //   queryParts.push(`created-by:${createdByUsernames}`);
    // }

    // if (data.created_before?.length) {
    //   queryParts.push(`created-before:${data.created_before}`);
    // }

    // if (data.created_after?.length) {
    //   queryParts.push(`created-after:${data.created_after}`);
    // }

    // if (data.order?.length) {
    //   queryParts.push(`order:${data.order}`);
    // }

    const queryString = queryParts.join(" ");
    this.args.updateTopicsListQueryParams(queryString);
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.args.updateTopicsListQueryParams(this.newQueryString);
  }

  @action
  copyQueryString() {
    this.copyIcon = "check";
    this.copyClass = "btn-default ok";

    navigator.clipboard.writeText(window.location);

    discourseDebounce(this._restoreButton, 3000);
  }

  @action
  toggleExpanded() {
    this.filterExpanded = !this.filterExpanded;
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.copyIcon = "link";
    this.copyClass = "btn-default";
  }

  <template>
    {{bodyClass "navigation-filter"}}

    <section class="navigation-container">
      <div class="topic-query-filter">
        {{#if (and this.site.mobileView @canBulkSelect)}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        <div class="topic-query-filter__input">
          <Form
            @onSubmit={{this.updateFilter}}
            @data={{this.formData}}
            as |form data|
          >
            <form.Field
              @name="query"
              @title="Query"
              @showTitle={{true}}
              as |field|
            >
              <field.Input />
            </form.Field>

            <Tags @form={{form}} @data={{data}} />

            <form.Actions>
              <form.Submit @label="form_templates.filter" />
            </form.Actions>
          </Form>

          {{!-- {{icon "filter" class="topic-query-filter__icon"}} --}}
          {{! EXPERIMENTAL OUTLET - don't use because it will be removed soon  }}
          <PluginOutlet
            @name="below-filter-input"
            @outletArgs={{hash
              updateQueryString=this.updateQueryString
              newQueryString=this.newQueryString
            }}
          />
        </div>
      </div>
    </section>
  </template>
}
