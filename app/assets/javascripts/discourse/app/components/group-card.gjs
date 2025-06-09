import { LinkTo } from "@ember/routing";
import AvatarFlair from "discourse/components/avatar-flair";
import GroupInfo from "discourse/components/group-info";
import GroupMembershipButton from "discourse/components/group-membership-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

const GroupCard = <template>
  <LinkTo
    @route="group.members"
    @model={{@group.name}}
    class="group-box"
    data-group-name={{@group.name}}
  >
    <div class="group-box-inner">
      <div class="group-info-wrapper">
        {{#if @group.flair_url}}
          <span class="group-avatar-flair">
            <AvatarFlair
              @flairName={{@group.name}}
              @flairUrl={{@group.flair_url}}
              @flairBgColor={{@group.flair_bg_color}}
              @flairColor={{@group.flair_color}}
            />
          </span>
        {{/if}}

        <span class="group-info">
          <GroupInfo @group={{@group}} />
          <div class="group-user-count">{{icon
              "user"
            }}{{@group.user_count}}</div>
        </span>
      </div>

      <div class="group-description">{{htmlSafe @group.bio_excerpt}}</div>

      <div class="group-membership">
        <GroupMembershipButton
          @tagName=""
          @model={{@group}}
          @showLogin={{routeAction "showLogin"}}
        >
          {{#if @group.is_group_owner}}
            <span class="is-group-owner">
              {{icon "shield-halved"}}
              {{i18n "groups.index.is_group_owner"}}
            </span>
          {{else if @group.is_group_user}}
            <span class="is-group-member">
              {{icon "check"}}
              {{i18n "groups.index.is_group_user"}}
            </span>
          {{else if @group.public_admission}}
            {{i18n "groups.index.public"}}
          {{else if @group.isPrivate}}
            {{icon "far-eye-slash"}}
            {{i18n "groups.index.private"}}
          {{else}}
            {{#if @group.automatic}}
              {{i18n "groups.index.automatic"}}
            {{else}}
              {{icon "ban"}}
              {{i18n "groups.index.closed"}}
            {{/if}}
          {{/if}}
        </GroupMembershipButton>

        <span>
          <PluginOutlet
            @name="group-index-box-after"
            @connectorTagName="div"
            @outletArgs={{lazyHash model=@group}}
          />
        </span>
      </div>
    </div>
  </LinkTo>
</template>;

export default GroupCard;
