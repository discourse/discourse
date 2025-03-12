import Component from "@ember/component";
import { on } from "@ember/modifier";
import CountI18n from "discourse/components/count-i18n";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default class SelectedPosts extends Component {
  <template>
    <p>
      <CountI18n
        @key="topic.multi_select.description"
        @count={{this.selectedPostsCount}}
      />
    </p>

    {{#if this.canSelectAll}}
      <p>
        <a class="select-all" href {{on "click" this.selectAll}}>
          {{i18n "topic.multi_select.select_all"}}
        </a>
      </p>
    {{/if}}

    {{#if this.canDeselectAll}}
      <p>
        <a href {{on "click" this.deselectAll}}>
          {{i18n "topic.multi_select.deselect_all"}}
        </a>
      </p>
    {{/if}}

    {{#if this.canDeleteSelected}}
      <DButton
        @action={{this.deleteSelected}}
        @icon="trash-can"
        @label="topic.multi_select.delete"
        class="btn-danger"
      />
    {{/if}}

    {{#if this.canMergeTopic}}
      <DButton
        @action={{routeAction "moveToTopic"}}
        @icon="right-from-bracket"
        @label="topic.move_to.action"
        class="btn-primary move-to-topic"
      />
    {{/if}}

    {{#if this.canChangeOwner}}
      <DButton
        @action={{routeAction "changeOwner"}}
        @icon="user"
        @label="topic.change_owner.action"
        class="btn-primary"
      />
    {{/if}}

    {{#if this.canMergePosts}}
      <DButton
        @action={{this.mergePosts}}
        @icon="up-down"
        @label="topic.merge_posts.action"
        class="btn-primary"
      />
    {{/if}}

    <p class="cancel">
      <a href {{on "click" this.toggleMultiSelect}}>
        {{i18n "topic.multi_select.cancel"}}
      </a>
    </p>
  </template>
}
