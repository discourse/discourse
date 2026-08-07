import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ShareTopicModal from "discourse/components/modal/share-topic";
import { relativeAge } from "discourse/lib/formatter";
import { and } from "discourse/truth-helpers";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostMetaDataDate extends Component {
  @service a11y;
  @service modal;

  get srDate() {
    if (this.a11y.autoUpdatingRelativeDateRef && this.args.post.displayDate) {
      return relativeAge(new Date(this.args.post.displayDate), {
        format: "medium-with-ago",
        wrapInSpan: false,
      });
    }
  }

  @action
  showShareModal(evt) {
    evt.preventDefault();

    const post = this.args.post;
    const topic = post.topic;

    this.modal.show(ShareTopicModal, {
      model: { category: topic.category, topic, post },
    });
  }

  <template>
    <div class="post-info post-date">
      <a
        class={{dConcatClass
          "post-date"
          (if (and @post.wiki @post.last_wiki_edit) "last-wiki-edit")
        }}
        href={{@post.shareUrl}}
        title={{i18n "post.sr_date"}}
        aria-label={{this.srDate}}
        {{on "click" this.showShareModal}}
      >
        <span aria-hidden="true">
          <DRelativeDate @date={{@post.displayDate}} />
        </span>
      </a>
    </div>
  </template>
}
