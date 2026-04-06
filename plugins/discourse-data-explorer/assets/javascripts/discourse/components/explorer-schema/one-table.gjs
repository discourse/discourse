/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import EnumInfo from "./enum-info";

export default class OneTable extends Component {
  @tracked open = this.args.table.open;

  get styles() {
    return this.open ? "open" : "";
  }

  @bind
  toggleOpen() {
    this.open = !this.open;
  }

  <template>
    <li class="schema-table {{this.styles}}">
      {{! template-lint-enable no-invalid-interactive }}
      <div
        class="schema-table-name"
        role="button"
        {{on "click" this.toggleOpen}}
      >
        {{#if this.open}}
          {{icon "angle-down"}}
        {{else}}
          {{icon "angle-right"}}
        {{/if}}
        {{@table.name}}
      </div>

      <div class="schema-table-cols">
        {{#if this.open}}
          <dl>
            {{#each @table.columns as |col|}}
              <div>
                <dt
                  class={{concatClass
                    (if col.sensitive "sensitive")
                    (if col.is_deprecated "deprecated")
                  }}
                  title={{concat
                    (if col.sensitive (i18n "explorer.schema.sensitive"))
                    (if col.is_deprecated col.deprecation_message)
                  }}
                >
                  {{#if col.sensitive}}
                    {{icon "triangle-exclamation"}}
                  {{/if}}
                  {{#if col.is_deprecated}}
                    {{icon "triangle-exclamation"}}
                  {{/if}}
                  <span class="column-name">{{col.column_name}}</span>
                  {{#if col.is_deprecated}}
                    <span class="extra-info">{{i18n
                        "explorer.schema.deprecated"
                      }}</span>
                  {{/if}}
                </dt>
                <dd>
                  {{col.data_type}}
                  {{#if col.havetypeinfo}}
                    <br />
                    {{#if col.havepopup}}
                      <div class="popup-info">
                        {{icon "info"}}
                        <div class="popup">
                          {{col.column_desc}}
                          {{#if col.enum}}
                            <EnumInfo @col={{col}} />
                          {{/if}}
                        </div>
                      </div>
                    {{/if}}
                    <span class="schema-typenotes">
                      {{col.notes}}
                    </span>
                  {{/if}}
                </dd>
              </div>
            {{/each}}
          </dl>
        {{/if}}
      </div>
    </li>
  </template>
}
