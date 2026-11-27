import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// Renders the items from ChannelActions. Closes before running the item, since
// most open a modal or dialog of their own. An item with `items` opens them in
// a submenu beside this one, the way chat's channel menu does.
export default class ActionMenu extends Component {
  @service menu;

  @action
  run(item) {
    this.args.close();
    item.action();
  }

  @action
  openSubmenu(item, _actionParam, event) {
    this.menu.show(event.target, {
      identifier: "concord-action-submenu",
      component: ActionMenu,
      data: { items: item.items },
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      onClose: () => this.args.close(),
    });
  }

  <template>
    <DDropdownMenu class="concord-action-menu" as |dropdown|>
      {{#each @data.items as |item|}}
        {{#if item.heading}}
          <dropdown.divider />
          <dropdown.subheader>{{item.heading}}</dropdown.subheader>
        {{else if item.divider}}
          <dropdown.divider />
        {{else if item.items}}
          <dropdown.item>
            <DButton
              class="btn-transparent"
              data-item-id={{item.id}}
              @action={{fn this.openSubmenu item}}
              @forwardEvent={{true}}
              @icon={{item.icon}}
              @suffixIcon="angle-right"
              @translatedLabel={{item.label}}
            />
          </dropdown.item>
        {{else}}
          <dropdown.item>
            <DButton
              class={{dConcatClass
                "btn-transparent"
                (if item.danger "--danger")
                (if item.checked "--checked")
                (unless (or item.icon item.checked) "--no-icon")
              }}
              data-item-id={{item.id}}
              @action={{fn this.run item}}
              @icon={{if item.checked "check" item.icon}}
              @translatedLabel={{item.label}}
            >
              {{#if item.badge}}
                <span class="concord-action-menu__badge">{{item.badge}}</span>
              {{/if}}
            </DButton>
          </dropdown.item>
        {{/if}}
      {{/each}}
    </DDropdownMenu>
  </template>
}
