import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import DButton from "discourse/components/d-button";
import DateInput from "discourse/components/date-input";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import CategorySelector from "select-kit/components/category-selector";
import TagChooser from "select-kit/components/tag-chooser";
import UserChooser from "select-kit/components/user-chooser";
import DMenu from "float-kit/components/d-menu";
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

  @cached
  get formData() {
    return {
      categories: [],
      tags: [],
      created_by: [],
      created_before: null,
      order: null,
      created_after: null,
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

    if (data.categories?.length) {
      const categoryNames = data.categories
        .map((category) => category.name)
        .join(",");
      queryParts.push(`categories:${categoryNames}`);
    }

    if (data.tags?.length) {
      const tagNames = data.tags.join(",");
      queryParts.push(`tags:${tagNames}`);
    }

    if (data.created_by?.length) {
      const createdByUsernames = data.created_by.join(",");
      queryParts.push(`created-by:${createdByUsernames}`);
    }

    if (data.created_before?.length) {
      queryParts.push(`created-before:${data.created_before}`);
    }

    if (data.created_after?.length) {
      queryParts.push(`created-after:${data.created_after}`);
    }

    if (data.order?.length) {
      queryParts.push(`order:${data.order}`);
    }

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
              @name="categories"
              @title="categories"
              @showTitle={{false}}
              as |field|
            >
              <field.Custom>
                <CategorySelector
                  @categories={{field.value}}
                  @onChange={{field.set}}
                />
              </field.Custom>
            </form.Field>

            <form.Field
              @name="tags"
              @title="tags"
              @showTitle={{false}}
              as |field|
            >
              <field.Custom>
                <TagChooser
                  @tags={{field.value}}
                  @everyTag={{true}}
                  @excludeSynonyms={{true}}
                  @unlimitedTagCount={{true}}
                  @onChange={{field.set}}
                  @options={{hash
                    filterPlaceholder="category.tags_placeholder"
                  }}
                />
              </field.Custom>
            </form.Field>

            <form.Field
              @name="created_by"
              @title="created_by"
              @showTitle={{false}}
              as |field|
            >
              <field.Custom>
                <UserChooser
                  @value={{field.value}}
                  @onChange={{field.set}}
                  @options={{hash maximum=10 excludeCurrentUser=false}}
                />
              </field.Custom>
            </form.Field>

            <form.Field
              @name="created_after"
              @title="created_after"
              @showTitle={{false}}
              as |field|
            >
              <field.Custom>
                <DateInput
                  max={{data.created_before}}
                  @date={{field.value}}
                  @onChange={{fn this.formatDate field.set}}
                />
              </field.Custom>
            </form.Field>

            <form.Field
              @name="created_before"
              @title="created_before"
              @showTitle={{false}}
              as |field|
            >
              <field.Custom>
                <DateInput
                  min={{data.created_after}}
                  @date={{field.value}}
                  @onChange={{fn this.formatDate field.set}}
                />
              </field.Custom>
            </form.Field>

            <form.Field
              @name="order"
              @title="order"
              @showTitle={{false}}
              as |field|
            >
              <field.Select as |select|>
                {{#each this.availableSorts as |availableSort|}}
                  <select.Option
                    @value={{availableSort}}
                  >{{availableSort}}</select.Option>
                {{/each}}
              </field.Select>
            </form.Field>

            <DMenu @identifier="advanced-filters" @icon="sliders">
              <:content>
                <form.Field
                  @name="foo"
                  @title="foo"
                  @showTitle={{false}}
                  as |field|
                >
                  <field.Input />
                </form.Field>
              </:content>
            </DMenu>

            <form.Submit />
          </Form>

          {{!-- {{icon "filter" class="topic-query-filter__icon"}} --}}
          <Input
            class="topic-query-filter__filter-term"
            @value={{this.newQueryString}}
            @enter={{action @updateTopicsListQueryParams this.newQueryString}}
            @type="text"
            id="queryStringInput"
            autocomplete="off"
          />
          {{! EXPERIMENTAL OUTLET - don't use because it will be removed soon  }}
          <PluginOutlet
            @name="below-filter-input"
            @outletArgs={{hash
              updateQueryString=this.updateQueryString
              newQueryString=this.newQueryString
            }}
          />
        </div>
        {{#if this.newQueryString}}
          <div class="topic-query-filter__controls">
            <DButton
              @icon="xmark"
              @action={{this.clearInput}}
              @disabled={{unless this.newQueryString "true"}}
            />

            {{!-- {{#if this.discoveryFilter.q}} --}}
            <DButton
              @icon={{this.copyIcon}}
              @action={{this.copyQueryString}}
              @disabled={{unless this.newQueryString "true"}}
              class={{this.copyClass}}
            />
            {{!-- {{/if}} --}}
          </div>
        {{/if}}
      </div>
    </section>
  </template>
}
