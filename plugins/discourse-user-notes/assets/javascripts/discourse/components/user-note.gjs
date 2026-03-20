import { fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

const UserNote = <template>
  <PluginOutlet
    @name="user-note-modal-wrapper"
    @outletArgs={{lazyHash note=@note removeNote=@removeNote}}
  >
    <div class="user-note">
      <div class="posted-by">
        <DUserLink @user={{@note.created_by}}>
          {{dAvatar @note.created_by imageSize="small"}}
        </DUserLink>
      </div>
      <div class="note-contents">
        <div class="note-info">
          <span class="username">{{@note.created_by.username}}</span>
          <span class="post-date">{{dAgeWithTooltip @note.created_at}}</span>
          {{#if @note.reviewable_id}}
            <LinkTo
              @route="review.show"
              @model={{@note.reviewable_id}}
              class="btn btn-small btn-default show-reviewable"
            >
              {{i18n "user_notes.show_flag"}}
            </LinkTo>
          {{/if}}
          {{#if @note.can_delete}}
            <DButton
              @action={{fn @removeNote @note}}
              @icon="far-trash-can"
              @title="user_notes.remove"
              class="btn-small btn-danger"
            />
          {{/if}}
        </div>

        <div class="cooked">
          <DCookText @rawText={{@note.raw}} />
        </div>
        {{#if @note.post_id}}
          <a href={{@note.post_url}} class="btn btn-small">
            {{i18n "user_notes.show_post"}}
          </a>
        {{/if}}
      </div>

      <div class="clearfix"></div>
    </div>
  </PluginOutlet>
</template>;

export default UserNote;
