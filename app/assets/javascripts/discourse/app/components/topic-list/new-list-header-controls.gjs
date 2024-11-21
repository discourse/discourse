import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class NewListHeaderControls extends Component {
  get topicsActive() {
    return this.args.current === "topics";
  }

  get repliesActive() {
    return this.args.current === "replies";
  }

  get allActive() {
    return !this.topicsActive && !this.repliesActive;
  }

  get repliesButtonLabel() {
    if (this.args.newRepliesCount > 0) {
      return i18n("filters.new.replies_with_count", {
        count: this.args.newRepliesCount,
      });
    } else {
      return i18n("filters.new.replies");
    }
  }

  get topicsButtonLabel() {
    if (this.args.newTopicsCount > 0) {
      return i18n("filters.new.topics_with_count", {
        count: this.args.newTopicsCount,
      });
    } else {
      return i18n("filters.new.topics");
    }
  }

  get staticLabel() {
    if (
      this.args.noStaticLabel ||
      (this.args.newTopicsCount > 0 && this.args.newRepliesCount > 0)
    ) {
      return;
    }

    if (this.args.newTopicsCount > 0) {
      return this.topicsButtonLabel;
    } else {
      return this.repliesButtonLabel;
    }
  }

  <template>
    {{#if this.staticLabel}}
      <span class="static-label">{{this.staticLabel}}</span>
    {{else}}
      <button
        {{on "click" (fn @changeNewListSubset null)}}
        class={{concatClass
          "topics-replies-toggle --all"
          (if this.allActive "active")
        }}
      >
        {{i18n "filters.new.all"}}
      </button>

      <button
        {{on "click" (fn @changeNewListSubset "topics")}}
        class={{concatClass
          "topics-replies-toggle --topics"
          (if this.topicsActive "active")
        }}
      >
        {{this.topicsButtonLabel}}
      </button>

      <button
        {{on "click" (fn @changeNewListSubset "replies")}}
        class={{concatClass
          "topics-replies-toggle --replies"
          (if this.repliesActive "active")
        }}
      >
        {{this.repliesButtonLabel}}
      </button>
    {{/if}}
  </template>
}
