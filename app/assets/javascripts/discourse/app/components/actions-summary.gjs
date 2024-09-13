import avatar from "discourse/helpers/bound-avatar-template";
import formatDate from "discourse/helpers/format-date";
import dIcon from "discourse-common/helpers/d-icon";

const ActionsSummary = <template>
  {{#each @data.actionsSummary as |as|}}
    <div class="post-action">{{as.description}}</div>
    <div class="clearfix"></div>
  {{/each}}
  {{#if @data.deleted_at}}
    <div class="post-action deleted-post">
      {{dIcon "trash-can"}}
      <a
        class="trigger-user-card"
        data-user-card={{@data.deletedByUsername}}
        title={{@data.deletedByUsername}}
        aria-hidden="true"
      >
        {{avatar
          @data.deletedByAvatarTemplate
          "tiny"
          title=@data.deletedByUsername
        }}
      </a>
      {{formatDate @data.deleted_at format="tiny"}}
    </div>
  {{/if}}
</template>;

export default ActionsSummary;
