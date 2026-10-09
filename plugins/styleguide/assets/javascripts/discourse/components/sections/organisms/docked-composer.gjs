import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DockedComposer from "discourse/components/docked-composer";
import withEventValue from "discourse/helpers/with-event-value";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class DockedComposerSection extends Component {
  @tracked resizable = true;
  @tracked disabled = false;
  @tracked placeholder = i18n("composer.reply_placeholder");
  submitTitle = "composer.reply";

  @action
  toggleResizable() {
    this.resizable = !this.resizable;
  }

  @action
  toggleDisabled() {
    this.disabled = !this.disabled;
  }

  @action
  async handleSubmit({ raw }) {
    // no-op: pretend the submission succeeded so the composer clears itself
    // eslint-disable-next-line no-console
    console.log("[styleguide] DockedComposer submit:", raw);
    return { ok: true };
  }

  <template>
    {{! eslint-disable ember/template-no-potential-path-strings }}
    <StyleguideExample @title="<DockedComposer>">
      <StyleguideComponent>
        <div class="docked-composer-styleguide">
          <DockedComposer
            @disabled={{this.disabled}}
            @draftKey="styleguide-docked-composer"
            @onSubmit={{this.handleSubmit}}
            @placeholder={{this.placeholder}}
            @resizable={{this.resizable}}
            @submitTitle={{this.submitTitle}}
            @uploaderId="styleguide-docked-composer-uploader"
            @uploadTitle="composer.upload_title"
          />
        </div>
      </StyleguideComponent>

      <Controls>
        <Row @name="@resizable">
          <DToggleSwitch
            @state={{this.resizable}}
            {{on "click" this.toggleResizable}}
          />
        </Row>
        <Row @name="@disabled">
          <DToggleSwitch
            @state={{this.disabled}}
            {{on "click" this.toggleDisabled}}
          />
        </Row>
        <Row @name="@placeholder">
          <input
            type="text"
            value={{this.placeholder}}
            {{on "input" (withEventValue (fn (mut this.placeholder)))}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
