import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import ShareTopicModal from "discourse/components/modal/share-topic";
import RelativeDate from "discourse/components/relative-date";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class PostMetaDataDate extends Component {
  @service modal;

  get date() {
    if (this.args.post.wiki && this.args.post.last_wiki_edit) {
      return this.args.post.last_wiki_edit;
    } else {
      return this.args.post.created_at;
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
        class={{concatClass
          "post-date"
          (if (and @post.wiki @post.last_wiki_edit) "last-wiki-edit")
        }}
        href={{@post.shareUrl}}
        title={{i18n "post.sr_date"}}
        {{on "click" this.showShareModal}}
      >
        <RelativeDate @date={{this.date}} />
      </a>
    </div>
  </template>
}
