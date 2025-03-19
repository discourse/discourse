import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class AppendTags extends Component {
  @tracked tags = [];
}

<p>{{i18n "topics.bulk.choose_append_tags"}}</p>

<p><TagChooser @tags={{this.tags}} @categoryId={{@categoryId}} /></p>

<DButton
  @action={{fn @performAndRefresh (hash type="append_tags" tags=this.tags)}}
  @disabled={{not this.tags}}
  @label="topics.bulk.append_tags"
  class="topic-bulk-actions__append-tags"
/>