import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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

  <template>
    <button
      class={{dConcatClass
        "topics-replies-toggle --all"
        (if this.allActive "active")
      }}
      title={{i18n "filters.new.all_tooltip"}}
      {{on "click" (fn @changeNewListSubset null)}}
    >
      {{i18n "filters.new.all"}}
    </button>

    <button
      class={{dConcatClass
        "topics-replies-toggle --topics"
        (if this.topicsActive "active")
      }}
      title={{i18n "filters.new.new_topics_tooltip"}}
      {{on "click" (fn @changeNewListSubset "topics")}}
    >
      {{this.topicsButtonLabel}}
    </button>

    <button
      class={{dConcatClass
        "topics-replies-toggle --replies"
        (if this.repliesActive "active")
      }}
      title={{i18n "filters.new.new_replies_tooltip"}}
      {{on "click" (fn @changeNewListSubset "replies")}}
    >
      {{this.repliesButtonLabel}}
    </button>
  </template>
}
