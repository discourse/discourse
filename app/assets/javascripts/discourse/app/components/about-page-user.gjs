import avatar from "discourse/helpers/avatar";
import { prioritizeNameInUx } from "discourse/lib/settings";
import UserLink from "./user-link";

const AboutPageUser = <template>
  <div data-username={{@user.username}} class="user-info small">
    <div class="user-image">
      <div class="user-image-inner">
        <UserLink @username={{@user.username}} @ariaHidden={{true}}>
          {{avatar @user imageSize="large"}}
        </UserLink>
      </div>
    </div>
    <div class="user-detail">
      <div class="name-line">
        <UserLink @username={{@user.username}}>
          <span class="username">
            {{#if (prioritizeNameInUx @user.name)}}
              {{@user.name}}
            {{else}}
              {{@user.username}}
            {{/if}}
          </span>
          <span class="name">
            {{#if (prioritizeNameInUx @user.name)}}
              {{@user.username}}
            {{else}}
              {{@user.name}}
            {{/if}}
          </span>
        </UserLink>
      </div>
      <div class="title">{{@user.title}}</div>
    </div>
  </div>
</template>;

export default AboutPageUser;
