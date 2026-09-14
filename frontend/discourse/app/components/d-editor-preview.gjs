import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";

export default class DEditorPreview extends Component {
  @action
  handlePreviewClick(event) {
    if (!event.target.closest(".d-editor-preview")) {
      return;
    }

    if (wantsNewWindow(event)) {
      return;
    }

    if (event.target.tagName === "A") {
      if (event.target.classList.contains("mention")) {
        this.appEvents.trigger(
          "d-editor:preview-click-user-card",
          event.target,
          event
        );
      }

      if (event.target.classList.contains("mention-group")) {
        this.appEvents.trigger(
          "d-editor:preview-click-group-card",
          event.target,
          event
        );
      }

      event.preventDefault();
      return false;
    }
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div
      class="d-editor-preview-wrapper {{if @forcePreview 'force-preview'}}"
      ...attributes
      {{on "click" this.handlePreviewClick}}
    >
      <DDecoratedHtml
        @className="d-editor-preview"
        @decorate={{@onPreviewUpdated}}
        @html={{trustHTML @preview}}
      />
      <span class="d-editor-plugin">
        <PluginOutlet
          @connectorTagName="div"
          @name="editor-preview"
          @outletArgs={{@outletArgs}}
        />
      </span>
    </div>
  </template>
}
