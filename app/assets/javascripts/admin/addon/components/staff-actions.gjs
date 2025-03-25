import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DiscourseURL from "discourse/lib/url";

@tagName("")
export default class StaffActions extends Component {
  @action
  openLinks(event) {
    const dataset = event.target.dataset;

    if (dataset.linkPostId) {
      event.preventDefault();

      this.store.find("post", dataset.linkPostId).then((post) => {
        DiscourseURL.routeTo(post.url);
      });
    } else if (dataset.linkTopicId) {
      event.preventDefault();

      DiscourseURL.routeTo(`/t/${dataset.linkTopicId}`);
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div class="table staff-actions" {{on "click" this.openLinks}}>
      {{yield}}
    </div>
  </template>
}
