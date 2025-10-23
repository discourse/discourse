import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import BadgeCard from "discourse/components/badge-card";
import BadgeTitle from "discourse/components/badge-title";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserInfo from "discourse/components/user-info";
import formatDate from "discourse/helpers/format-date";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
          @count={{@controller.userBadges.grant_count}}
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
            class="badge-set-title
              {{if @controller.hiddenSetTitle 'hidden' ''}}"
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
                    {{htmlSafe
                      (i18n "badges.granted_on" date=(formatDate ub.granted_at))
                    }}
                  </div>

                  {{#if ub.post_number}}
                    <a
                      class="post-link"
                      href="{{ub.topic.url}}/{{ub.post_number}}"
                    >{{htmlSafe ub.topic.fancyTitle}}</a>
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
                >{{i18n
                    "badges.others_count"
                    count=@controller.othersCount
                  }}</a>
              </div>
            {{/if}}
          {{/unless}}
        </div>

        <ConditionalLoadingSpinner @condition={{@controller.canLoadMore}} />
      {{/if}}
    </div>
  </template>
);
