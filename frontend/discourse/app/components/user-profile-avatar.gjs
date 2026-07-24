/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DUserAvatarFlair from "discourse/ui-kit/d-user-avatar-flair";
import dBoundAvatar from "discourse/ui-kit/helpers/d-bound-avatar";

@tagName("")
export default class UserProfileAvatar extends Component {
  <template>
    <PluginOutlet
      @name="user-profile-avatar-wrapper"
      @outletArgs={{lazyHash user=@user}}
    >
      <div class="user-profile-avatar">
        <PluginOutlet
          @name="user-profile-avatar-img-wrapper"
          @outletArgs={{lazyHash user=@user}}
        >
          {{dBoundAvatar @user "huge"}}
        </PluginOutlet>

        <DUserAvatarFlair @user={{@user}} />
        <div>
          <PluginOutlet
            @name="user-profile-avatar-flair"
            @outletArgs={{lazyHash model=@user}}
          />
        </div>
      </div>
    </PluginOutlet>
  </template>
}
