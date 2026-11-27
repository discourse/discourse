import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import { i18n } from "discourse-i18n";
import AttributesMenu from "./attributes-menu.gjs";
import FieldMenu from "./field-menu.gjs";

const FieldHeader = <template>
  {{#if @onSetRequired}}
    <DButton
      class="btn-default btn-small form-definition-editor__requirement"
      @action={{@onSetRequired}}
      @actionParam={{not @required}}
      @ariaPressed={{or @required false}}
      @label={{if
        @required
        "form_definition.required"
        "form_definition.optional"
      }}
      @title={{if
        @required
        "form_definition.make_optional"
        "form_definition.make_required"
      }}
      @translatedAriaLabel={{i18n
        "form_definition.required_response"
        label=@label
      }}
    />
  {{/if}}
  <div class="form-definition-editor__field-menus">
    {{#if (or @onSetRequired (has-block))}}
      <AttributesMenu
        class="btn-small form-definition-editor__attributes"
        @inline={{@inlineMenus}}
        @label={{i18n "form_definition.attributes"}}
        @title={{i18n "form_definition.field_attributes" label=@label}}
        as |Attribute|
      >
        {{#if @onSetRequired}}
          <Attribute
            data-field-attribute="required"
            @active={{or @required false}}
            @label={{i18n "form_definition.required"}}
            @onToggle={{fn @onSetRequired (not @required)}}
          />
        {{/if}}
        {{yield Attribute}}
      </AttributesMenu>
    {{/if}}
    <FieldMenu
      @inlineMenus={{@inlineMenus}}
      @label={{@label}}
      @onMoveDown={{@onMoveDown}}
      @onMoveUp={{@onMoveUp}}
      @onRemove={{@onRemove}}
    />
  </div>
</template>;

export default class FieldList extends Component {
  @service a11y;

  listId = dUniqueId();
  addId = dUniqueId();

  // Some callers have no stored field IDs. Keep their editing state attached
  // to the row across moves without adding keys to their saved definitions.
  #keys = [];

  get lastIndex() {
    return this.args.fields.length - 1;
  }

  get rows() {
    return this.args.fields.map((field, index) => ({
      field,
      key: this.args.key ? field[this.args.key] : (this.#keys[index] ?? index),
    }));
  }

  @action
  add() {
    this.#setRows([
      ...this.rows,
      { key: dUniqueId(), field: this.args.newField() },
    ]);
  }

  @action
  move(index, offset) {
    const rows = this.rows;
    const destination = index + offset;
    if (destination < 0 || destination >= rows.length) {
      return;
    }
    const [row] = rows.splice(index, 1);
    rows.splice(destination, 0, row);
    this.#setRows(rows);
    this.a11y.announce(
      i18n("reorder.announcement", {
        label: this.args.labelFor(row.field),
        position: destination + 1,
        total: rows.length,
      })
    );
    this.#focusFieldMenu(destination);
  }

  @action
  remove(index) {
    const rows = this.rows;
    const [row] = rows.splice(index, 1);
    this.#setRows(rows);
    this.a11y.announce(
      i18n("reorder.removed", { label: this.args.labelFor(row.field) })
    );
    this.#focusFieldMenu(Math.min(index, rows.length - 1));
  }

  #setRows(rows) {
    this.#keys = rows.map((row) => row.key);
    this.args.onChange(rows.map((row) => row.field));
  }

  #focusFieldMenu(index) {
    next(() => {
      const card = document.getElementById(this.listId)?.children[index];
      const button =
        card?.querySelector(".form-definition-editor__field-menu") ??
        document.getElementById(this.addId);
      button?.focus();
    });
  }

  <template>
    <ol class="form-definition-editor__questions" id={{this.listId}}>
      {{#each this.rows key="key" as |row index|}}
        <li class="form-definition-editor__question">
          {{yield
            row.field
            index
            (component
              FieldHeader
              label=(@labelFor row.field)
              inlineMenus=@inlineMenus
              onMoveUp=(if (gt index 0) (fn this.move index -1))
              onMoveDown=(if (lt index this.lastIndex) (fn this.move index 1))
              onRemove=(if
                (gt @fields.length (or @minimum 0)) (fn this.remove index)
              )
            )
          }}
        </li>
      {{/each}}
    </ol>
    <@form.Button
      class="btn-default form-definition-editor__add"
      id={{this.addId}}
      @action={{this.add}}
      @disabled={{and @limit (gte @fields.length @limit)}}
      @icon="plus"
      @label="form_definition.add_field"
    />
  </template>
}
