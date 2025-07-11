import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
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
          {{icon "caret-down"}}
        {{else}}
          {{icon "caret-right"}}
        {{/if}}
        {{@table.name}}
      </div>

      <div class="schema-table-cols">
        {{#if this.open}}
          <dl>
            {{#each @table.columns as |col|}}
              <div>
                <dt
                  class={{if col.sensitive "sensitive"}}
                  title={{if col.sensitive (i18n "explorer.schema.sensitive")}}
                >
                  {{#if col.sensitive}}
                    {{icon "triangle-exclamation"}}
                  {{/if}}
                  {{col.column_name}}
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
