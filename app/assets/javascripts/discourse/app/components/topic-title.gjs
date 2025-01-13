import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import { isiPad } from "discourse/lib/utilities";
import observeIntersection from "discourse/modifiers/observe-intersection";

export default class TopicTitle extends Component {
  @service header;

  @action
  keyDown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.args.cancelled();
    } else if (
      e.key === "Enter" &&
      (e.ctrlKey || e.metaKey || (isiPad() && e.altKey))
    ) {
      // Ctrl+Enter or Cmd+Enter
      // iPad physical keyboard does not offer Command or Ctrl detection
      // so use Alt+Enter
      e.preventDefault();
      this.args.save(undefined, e);
    }
  }

  @action
  handleIntersectionChange(e) {
    // Title is in the viewport or  below it – unusual, but can be caused by
    // small viewport and/or large headers. Treat same as if title is on screen.
    this.header.mainTopicTitleVisible =
      e.isIntersecting || e.boundingClientRect.top > 0;
  }

  @action
  handleTitleDestroy() {
    this.header.mainTopicTitleVisible = false;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      {{on "keydown" this.keyDown}}
      {{observeIntersection this.handleIntersectionChange}}
      {{willDestroy this.handleTitleDestroy}}
      id="topic-title"
      class="container"
    >
      <div class="title-wrapper">
        {{yield}}
      </div>

      <PluginOutlet
        @name="topic-title"
        @connectorTagName="div"
        @outletArgs={{hash model=@model}}
      />
    </div>
  </template>
}
