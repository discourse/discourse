import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const PermissionTrigger = <template>
  <button
    class="btn btn-default d-access-control__permission d-access-control-permission-menu"
    disabled={{@disabled}}
    type="button"
    ...attributes
  >
    <span class="d-button-label">{{@label}}</span>
    {{dIcon "angle-down"}}
  </button>
</template>;

export default class DAccessControlPermissionMenu extends Component {
  get label() {
    return this.args.options.find((option) => option.id === this.args.value)
      ?.name;
  }

  @action
  select(close, permission) {
    close();
    this.args.onChange(permission);
  }

  <template>
    <DMenu
      data-permission={{@value}}
      ...attributes
      @autofocus={{false}}
      @disabled={{@disabled}}
      @identifier="d-access-control__permission-menu"
      @modalForMobile={{true}}
      @triggerComponent={{component
        PermissionTrigger
        disabled=@disabled
        label=this.label
      }}
    >
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#each @options key="id" as |option|}}
            {{#if (eq option.id "remove")}}
              <dropdown.divider />
            {{/if}}
            <dropdown.item>
              <DButton
                class={{dConcatClass
                  "d-access-control__permission-option"
                  "--with-description"
                  (if (eq option.id "remove") "--remove")
                  (if (eq option.id @value) "-selected")
                }}
                data-permission-id={{option.id}}
                @action={{fn this.select menu.close option.id}}
              >
                <div class="d-access-control__permission-texts">
                  <span
                    class="d-access-control__permission-label"
                  >{{option.name}}</span>
                  {{#if option.description}}
                    <span
                      class="d-access-control__permission-description"
                    >{{option.description}}</span>
                  {{/if}}
                </div>
              </DButton>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
