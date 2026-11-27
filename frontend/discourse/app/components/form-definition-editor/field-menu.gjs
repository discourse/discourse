import { fn } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

async function selectFieldAction(closeMenu, callback) {
  await closeMenu();
  callback();
}

export default <template>
  {{#let (i18n "form_definition.field_actions" label=@label) as |menuLabel|}}
    <DMenu
      @ariaLabel={{menuLabel}}
      @icon="ellipsis"
      @inline={{@inlineMenus}}
      @placement="bottom-end"
      @title={{menuLabel}}
      @triggerClass="btn-default btn-small form-definition-editor__field-menu"
    >
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#if (or @onMoveUp @onMoveDown)}}
            <dropdown.item>
              <DButton
                class="btn-transparent"
                data-field-action="up"
                @action={{fn selectFieldAction menu.close @onMoveUp}}
                @disabled={{not @onMoveUp}}
                @icon="arrow-up"
                @label="reorder.move_up"
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="btn-transparent"
                data-field-action="down"
                @action={{fn selectFieldAction menu.close @onMoveDown}}
                @disabled={{not @onMoveDown}}
                @icon="arrow-down"
                @label="reorder.move_down"
              />
            </dropdown.item>
            <dropdown.divider />
          {{/if}}
          <dropdown.item>
            <DButton
              class="btn-transparent --danger"
              data-field-action="remove"
              @action={{fn selectFieldAction menu.close @onRemove}}
              @disabled={{not @onRemove}}
              @icon="trash-can"
              @label="form_definition.delete_field"
            />
          </dropdown.item>
        </DDropdownMenu>
      </:content>
    </DMenu>
  {{/let}}
</template>
