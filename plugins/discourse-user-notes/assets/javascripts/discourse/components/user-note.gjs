import { fn } from "@ember/helper";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserLink from "discourse/components/user-link";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

const UserNote = <template>
  <PluginOutlet
    @name="user-note-modal-wrapper"
    @outletArgs={{lazyHash note=@note removeNote=@removeNote}}
  >
    <div class="user-note">
      <div class="posted-by">
        <UserLink @user={{@note.created_by}}>
          {{avatar @note.created_by imageSize="small"}}
        </UserLink>
      </div>
      <div class="note-contents">
        <div class="note-info">
          <span class="username">{{@note.created_by.username}}</span>
          <span class="post-date">{{ageWithTooltip @note.created_at}}</span>
          {{#if @note.can_delete}}
            <span class="controls">
              <DButton
                @action={{fn @removeNote @note}}
                @icon="far-trash-can"
                @title="user_notes.remove"
                class="btn-small btn-danger"
              />
            </span>
          {{/if}}
        </div>

        <div class="cooked">
          <CookText @rawText={{@note.raw}} />
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
