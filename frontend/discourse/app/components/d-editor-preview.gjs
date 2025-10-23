import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DecoratedHtml from "discourse/components/decorated-html";
import PluginOutlet from "discourse/components/plugin-outlet";
import { wantsNewWindow } from "discourse/lib/intercept-click";

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
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="d-editor-preview-wrapper {{if @forcePreview 'force-preview'}}"
      {{on "click" this.handlePreviewClick}}
    >
      <DecoratedHtml
        @className="d-editor-preview"
        @html={{htmlSafe @preview}}
        @decorate={{@onPreviewUpdated}}
      />
      <span class="d-editor-plugin">
        <PluginOutlet
          @name="editor-preview"
          @connectorTagName="div"
          @outletArgs={{@outletArgs}}
        />
      </span>
    </div>
  </template>
}
