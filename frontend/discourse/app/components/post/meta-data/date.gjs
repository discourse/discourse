import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ShareTopicModal from "discourse/components/modal/share-topic";
import { and } from "discourse/truth-helpers";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostMetaDataDate extends Component {
  @service modal;

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
        {{on "click" this.showShareModal}}
      >
        <DRelativeDate @date={{@post.displayDate}} />
      </a>
    </div>
  </template>
}
