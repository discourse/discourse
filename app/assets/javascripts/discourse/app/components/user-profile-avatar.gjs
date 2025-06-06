import Component from "@ember/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import boundAvatar from "discourse/helpers/bound-avatar";
import lazyHash from "discourse/helpers/lazy-hash";

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
          {{boundAvatar @user "huge"}}
        </PluginOutlet>

        <UserAvatarFlair @user={{@user}} />
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
