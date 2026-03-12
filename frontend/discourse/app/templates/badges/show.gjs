import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import BadgeCard from "discourse/ui-kit/d-badge-card";
import BadgeTitle from "discourse/ui-kit/d-badge-title";
import DButton from "discourse/ui-kit/d-button";
import ConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import LoadMore from "discourse/ui-kit/d-load-more";
import UserInfo from "discourse/ui-kit/d-user-info";
import formatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}

  <div class="container show-badge {{@controller.model.slug}}">
    <h1>
      <LinkTo @route="badges.index">{{i18n "badges.title"}}</LinkTo>
      /
      {{@controller.model.name}}
    </h1>

    <div class="show-badge-details">
      <BadgeCard
        @badge={{@controller.model}}
        @size="large"
        @count={{@controller.userBadgesGrantCount}}
      />
      <div
        class="badge-grant-info {{if @controller.hiddenSetTitle '' 'hidden'}}"
      >
        <div>
          {{#if @controller.canSelectTitle}}
            <div class="grant-info-item">
              {{i18n "badges.allow_title"}}
              <DButton
                @action={{@controller.toggleSetUserTitle}}
                @icon="pencil"
                class="btn-default pad-left"
              />
            </div>
          {{/if}}
          {{#if @controller.model.multiple_grant}}
            <div class="grant-info-item">
              {{i18n "badges.multiple_grant"}}
            </div>
          {{/if}}
        </div>
      </div>

      {{#if @controller.canSelectTitle}}
        <div
          class="badge-set-title {{if @controller.hiddenSetTitle 'hidden' ''}}"
        >
          <PluginOutlet
            @name="selectable-user-badges"
            @outletArgs={{lazyHash
              selectableUserBadges=@controller.selectableUserBadges
              closeAction=@controller.toggleSetUserTitle
            }}
          >
            <BadgeTitle
              @selectableUserBadges={{@controller.selectableUserBadges}}
              @closeAction={{@controller.toggleSetUserTitle}}
            />
          </PluginOutlet>
        </div>
      {{/if}}
    </div>

    {{#if @controller.userBadges}}
      <div class="user-badges {{@controller.model.slug}}">
        <LoadMore @action={{@controller.loadMore}}>
          <div class="badges-granted">
            {{#each @controller.userBadges as |ub|}}
              <UserInfo
                @user={{ub.user}}
                @size="medium"
                @date={{ub.granted_at}}
                class="badge-info"
              >
                <div class="granted-on">
                  {{trustHTML
                    (i18n "badges.granted_on" date=(formatDate ub.granted_at))
                  }}
                </div>

                {{#if ub.post_number}}
                  <a
                    class="post-link"
                    href="{{ub.topic.url}}/{{ub.post_number}}"
                  >{{trustHTML ub.topic.fancyTitle}}</a>
                {{/if}}
              </UserInfo>
            {{/each}}
          </div>
        </LoadMore>

        {{#unless @controller.canLoadMore}}
          {{#if @controller.canShowOthers}}
            <div>
              <a
                id="show-others-with-badge-link"
                href={{@controller.model.url}}
                class="btn btn-default"
              >{{i18n "badges.others_count" count=@controller.othersCount}}</a>
            </div>
          {{/if}}
        {{/unless}}
      </div>

      <ConditionalLoadingSpinner @condition={{@controller.canLoadMore}} />
    {{/if}}
  </div>
</template>
