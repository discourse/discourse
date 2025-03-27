import Component from "@ember/component";
import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import boundAvatar from "discourse/helpers/bound-avatar";

export default class UserProfileAvatar extends Component {
  <template>
    <PluginOutlet
      @name="user-profile-avatar-wrapper"
      @outletArgs={{hash user=@user}}
    >
      <div class="user-profile-avatar">
        <PluginOutlet
          @name="user-profile-avatar-img-wrapper"
          @outletArgs={{hash user=@user}}
        >
          {{boundAvatar @user "huge"}}
        </PluginOutlet>

        <UserAvatarFlair @user={{@user}} />
        <div>
          <PluginOutlet
            @name="user-profile-avatar-flair"
            @outletArgs={{hash model=@user}}
          />
        </div>
      </div>
    </PluginOutlet>
  </template>
}
