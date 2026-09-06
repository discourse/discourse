import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isBlank, isEmpty } from "@ember/utils";
import withEventValue from "discourse/helpers/with-event-value";
import { debounce } from "discourse/lib/decorators";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import OneTable from "./explorer-schema/one-table";

export default class ExplorerSchema extends Component {
  @tracked filter;
  @tracked loading;

  get transformedSchema() {
    const schema = this.args.schema;
    for (const key in schema) {
      if (!schema.hasOwnProperty(key)) {
        continue;
      }

      schema[key].forEach((col) => {
        const notes_components = [];
        if (col.primary) {
          notes_components.push("primary key");
        }
        if (col.is_nullable) {
          notes_components.push("null");
        }
        if (col.column_default) {
          notes_components.push("default " + col.column_default);
        }
        if (col.fkey_info) {
          notes_components.push("fkey " + col.fkey_info);
        }
        if (col.denormal) {
          notes_components.push("denormal " + col.denormal);
        }
        const notes = notes_components.join(", ");

        if (notes) {
          col.notes = notes;
        }

        if (col.enum || col.column_desc) {
          col.havepopup = true;
        }

        col.havetypeinfo = !!(col.notes || col.enum || col.column_desc);
      });
    }
    return schema;
  }

  get filteredTables() {
    let tables = [];
    let filter = this.filter;

    try {
      if (!isBlank(this.filter)) {
        filter = new RegExp(this.filter);
      }
    } catch {
      filter = null;
    }

    const haveFilter = !!filter;

    for (const key in this.transformedSchema) {
      if (!this.transformedSchema.hasOwnProperty(key)) {
        continue;
      }
      if (!haveFilter) {
        tables.push({
          name: key,
          columns: this.transformedSchema[key],
          open: false,
        });
        continue;
      }

      if (filter.source === key || filter.source + "s" === key) {
        tables.unshift({
          name: key,
          columns: this.transformedSchema[key],
          open: haveFilter,
        });
      } else if (filter.test(key)) {
        tables.push({
          name: key,
          columns: this.transformedSchema[key],
          open: haveFilter,
        });
      } else {
        let filterCols = [];
        this.transformedSchema[key].forEach((col) => {
          if (filter.source === col.column_name) {
            filterCols.unshift(col);
          } else if (filter.test(col.column_name)) {
            filterCols.push(col);
          }
        });
        if (!isEmpty(filterCols)) {
          tables.push({
            name: key,
            columns: filterCols,
            open: haveFilter,
          });
        }
      }
    }
    return tables;
  }

  @debounce(500)
  updateFilter(value) {
    this.filter = value.toLowerCase();
    this.loading = false;
  }

  @action
  filterChanged(value) {
    this.loading = true;
    this.updateFilter(value);
  }

  @action
  collapseSchema() {
    this.args.updateHideSchema(true);
  }

  @action
  expandSchema() {
    this.args.updateHideSchema(false);
  }

  <template>
    {{#if @hideSchema}}
      <DButton
        @action={{this.expandSchema}}
        @icon="chevron-left"
        @ariaLabel="explorer.schema.show"
        class="schema__toggle --expand no-text unhide"
      />
    {{else}}
      <div class="schema">
        <div class="schema-search">
          {{dIcon "magnifying-glass" class="schema-search__icon"}}
          <input
            type="text"
            class="schema-search__input"
            placeholder={{i18n "explorer.schema.search_tables"}}
            {{on "input" (withEventValue this.filterChanged)}}
          />
          <DButton
            @action={{this.collapseSchema}}
            @icon="chevron-right"
            @ariaLabel="explorer.schema.hide"
            class="schema__toggle --collapse no-text"
          />
        </div>

        <div class="schema-container">
          <DConditionalLoadingSpinner @condition={{this.loading}}>
            <ul>
              {{#each this.filteredTables as |table|}}
                <OneTable @table={{table}} />
              {{/each}}
            </ul>
          </DConditionalLoadingSpinner>
        </div>
      </div>
    {{/if}}
  </template>
}
