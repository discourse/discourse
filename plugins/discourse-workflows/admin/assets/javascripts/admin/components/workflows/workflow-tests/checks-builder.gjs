import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  CHECK_MODES,
  checkSentence,
  CONDITION_OPERATORS,
  fieldsForEffect,
  isSpecialCheck,
  newCheck,
  newCondition,
  SPECIAL_CHECKS,
} from "../../../lib/workflows/workflow-test-checks.js";

export default class ChecksBuilder extends Component {
  specialChecks = SPECIAL_CHECKS;
  modes = CHECK_MODES;
  operators = CONDITION_OPERATORS;

  sentence = (check) => checkSentence(check);

  fieldsFor = (check) => fieldsForEffect(check.effect);

  isSpecial = (check) => isSpecialCheck(check.effect);

  get effectTypes() {
    return (this.args.effectTypes ?? []).map((entry) => entry.type);
  }

  @action
  addCheck() {
    this.args.form.addItemToCollection("checks", newCheck());
  }

  @action
  addCondition(index, check) {
    this.args.form.addItemToCollection(
      `checks.${index}.conditions`,
      newCondition(check.effect)
    );
  }

  @action
  effectChanged(index, value, { set, name }) {
    set(name, value);
    set(`checks.${index}.conditions`, []);
    if (isSpecialCheck(value)) {
      set(`checks.${index}.mode`, "happens");
    }
  }

  <template>
    <@form.Collection @name="checks" @tagName="div" as |collection index check|>
      <div class="workflows-test-checks__row">
        <div class="workflows-test-checks__fields">
          <@form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field
                @name="effect"
                @onSet={{fn this.effectChanged index}}
                @title={{i18n "discourse_workflows.tests.editor.effect"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <field.Control as |select|>
                  {{#each this.effectTypes as |effect|}}
                    <select.Option @value={{effect}}>
                      {{i18n
                        (concat "discourse_workflows.tests.effects." effect)
                        count=1
                      }}
                    </select.Option>
                  {{/each}}
                  {{#each this.specialChecks as |effect|}}
                    <select.Option @value={{effect}}>
                      {{i18n
                        (concat "discourse_workflows.tests.sentences." effect)
                      }}
                    </select.Option>
                  {{/each}}
                </field.Control>
              </collection.Field>
            </row.Col>

            {{#unless (this.isSpecial check)}}
              <row.Col @size={{4}}>
                <collection.Field
                  @name="mode"
                  @title={{i18n "discourse_workflows.tests.editor.mode"}}
                  @type="select"
                  as |field|
                >
                  <field.Control as |select|>
                    {{#each this.modes as |mode|}}
                      <select.Option @value={{mode}}>
                        {{i18n
                          (concat "discourse_workflows.tests.modes." mode)
                        }}
                      </select.Option>
                    {{/each}}
                  </field.Control>
                </collection.Field>
              </row.Col>

              {{#if (eq check.mode "count")}}
                <row.Col @size={{2}}>
                  <collection.Field
                    @name="count"
                    @title={{i18n "discourse_workflows.tests.editor.count"}}
                    @type="input-number"
                    as |field|
                  >
                    <field.Control min="0" />
                  </collection.Field>
                </row.Col>
              {{/if}}
            {{/unless}}
          </@form.Row>

          {{#unless (this.isSpecial check)}}
            <collection.Collection
              @name="conditions"
              @tagName="div"
              as |conditions conditionIndex|
            >
              <div class="workflows-test-checks__condition">
                <@form.Row as |row|>
                  <row.Col @size={{4}}>
                    <conditions.Field
                      @name="field"
                      @title={{i18n "discourse_workflows.tests.editor.field"}}
                      @type="select"
                      as |field|
                    >
                      <field.Control as |select|>
                        {{#each (this.fieldsFor check) as |name|}}
                          <select.Option @value={{name}}>
                            {{i18n
                              (concat
                                "discourse_workflows.tests.fields."
                                check.effect
                                "."
                                name
                              )
                            }}
                          </select.Option>
                        {{/each}}
                      </field.Control>
                    </conditions.Field>
                  </row.Col>
                  <row.Col @size={{3}}>
                    <conditions.Field
                      @name="operator"
                      @title={{i18n
                        "discourse_workflows.tests.editor.operator"
                      }}
                      @type="select"
                      as |field|
                    >
                      <field.Control as |select|>
                        {{#each this.operators as |operator|}}
                          <select.Option @value={{operator}}>
                            {{i18n
                              (concat
                                "discourse_workflows.if.operators." operator
                              )
                            }}
                          </select.Option>
                        {{/each}}
                      </field.Control>
                    </conditions.Field>
                  </row.Col>
                  <row.Col @size={{4}}>
                    <conditions.Field
                      @name="value"
                      @title={{i18n "discourse_workflows.tests.editor.value"}}
                      @type="input"
                      as |field|
                    >
                      <field.Control />
                    </conditions.Field>
                  </row.Col>
                  <row.Col @size={{1}}>
                    <DButton
                      class="btn-transparent btn-small btn-danger workflows-test-checks__remove-condition"
                      @action={{fn conditions.remove conditionIndex}}
                      @icon="trash-can"
                      @title="discourse_workflows.tests.editor.remove_condition"
                    />
                  </row.Col>
                </@form.Row>
              </div>
            </collection.Collection>

            <DButton
              class="btn-transparent btn-small workflows-test-checks__add-condition"
              @action={{fn this.addCondition index check}}
              @icon="plus"
              @label="discourse_workflows.tests.editor.add_condition"
            />
          {{/unless}}

          <p class="workflows-test-checks__sentence">
            {{dIcon "quote-left"}}
            {{this.sentence check}}
          </p>
        </div>

        <DButton
          class="btn-transparent btn-small btn-danger workflows-test-checks__remove"
          @action={{fn collection.remove index}}
          @icon="trash-can"
          @title="discourse_workflows.tests.delete"
        />
      </div>
    </@form.Collection>

    <DButton
      class="btn-default workflows-test-checks__add"
      @action={{this.addCheck}}
      @icon="plus"
      @label="discourse_workflows.tests.editor.add_check"
    />
  </template>
}
