import { on } from "@ember/modifier";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import { i18n } from "discourse-i18n";

const SelectedPosts = <template>
  <div ...attributes>
    <p>
      <DCountI18n
        @count={{@selectedPostsCount}}
        @key="topic.multi_select.description"
      />
    </p>

    {{#if @canSelectAll}}
      <p>
        <a class="select-all" href {{on "click" @selectAll}}>
          {{i18n "topic.multi_select.select_all"}}
        </a>
      </p>
    {{/if}}

    {{#if @canDeselectAll}}
      <p>
        <a href {{on "click" @deselectAll}}>
          {{i18n "topic.multi_select.deselect_all"}}
        </a>
      </p>
    {{/if}}

    {{#if @canDeleteSelected}}
      <DButton
        class="btn-danger"
        @action={{@deleteSelected}}
        @icon="trash-can"
        @label="topic.multi_select.delete"
      />
    {{/if}}

    {{#if @canMergeTopic}}
      <DButton
        class="btn-primary move-to-topic"
        @action={{routeAction "moveToTopic"}}
        @icon="right-from-bracket"
        @label="topic.move_to.action"
      />
    {{/if}}

    {{#if @canChangeOwner}}
      <DButton
        class="btn-primary"
        @action={{routeAction "changeOwner"}}
        @icon="user"
        @label="topic.change_owner.action"
      />
    {{/if}}

    {{#if @canMergePosts}}
      <DButton
        class="btn-primary"
        @action={{@mergePosts}}
        @icon="up-down"
        @label="topic.merge_posts.action"
      />
    {{/if}}

    <p class="cancel">
      <a href {{on "click" @toggleMultiSelect}}>
        {{i18n "topic.multi_select.cancel"}}
      </a>
    </p>
  </div>
</template>;

export default SelectedPosts;
