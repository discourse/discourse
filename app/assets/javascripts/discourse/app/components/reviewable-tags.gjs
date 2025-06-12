import Component from "@ember/component";
import { or } from "truth-helpers";
import discourseTags from "discourse/helpers/discourse-tags";

export default class ReviewableTags extends Component {
  <template>
    {{#if @tags}}
      <div class="list-tags">
        {{discourseTags (or @topic null) tags=@tags}}
      </div>
    {{/if}}
  </template>
}
