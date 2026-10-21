import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DTabs from "discourse/ui-kit/d-tabs";

export default class TabsVerticalExample extends Component {
  @tracked active = "account";

  @action
  activate(id) {
    this.active = id;
  }

  <template>
    <div class="styleguide-tabs --vertical">
      <DTabs
        @active={{this.active}}
        @label="Preference sections"
        @onActivate={{this.activate}}
        @orientation="vertical"
        as |tabs|
      >
        <tabs.Tab @key="account" @label="Account">
          <p>Up and Down move along the strip. Left and Right do nothing here,
            because a tablist has one axis.</p>
        </tabs.Tab>
        <tabs.Tab @key="notifications" @label="Notifications">
          <p>The tablist announces its vertical orientation, which assistive
            technology otherwise assumes horizontal.</p>
        </tabs.Tab>
        <tabs.Tab @key="interface" @label="Interface">
          <p>Placing the strip beside the panel is the consumer's layout; the
            widget stacks the strip and wraps long labels itself.</p>
        </tabs.Tab>
        <tabs.Tab @key="security" @label="Security">
          <p>Home and End jump to the first and last tab on either axis.</p>
        </tabs.Tab>
      </DTabs>
    </div>
  </template>
}
