import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import BadgeTitle from "discourse/components/badge-title";
import PluginOutlet from "discourse/components/plugin-outlet";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import DBadgeCard from "discourse/ui-kit/d-badge-card";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DUserInfo from "discourse/ui-kit/d-user-info";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
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
      <DBadgeCard
        @badge={{@controller.model}}
        @count={{@controller.userBadgesGrantCount}}
        @size="large"
      />
      <div
        class="badge-grant-info {{if @controller.hiddenSetTitle '' 'hidden'}}"
      >
        <div>
          {{#if @controller.canSelectTitle}}
            <div class="grant-info-item">
              {{i18n "badges.allow_title"}}
              <DButton
                class="btn-default pad-left"
                @action={{@controller.toggleSetUserTitle}}
                @icon="pencil"
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
              @closeAction={{@controller.toggleSetUserTitle}}
              @selectableUserBadges={{@controller.selectableUserBadges}}
            />
          </PluginOutlet>
        </div>
      {{/if}}
    </div>

    {{#if @controller.userBadges}}
      <div class="user-badges {{@controller.model.slug}}">
        <DLoadMore @action={{@controller.loadMore}}>
          <div class="badges-granted">
            {{#each @controller.userBadges as |ub|}}
              <DUserInfo
                class="badge-info"
                @date={{ub.granted_at}}
                @size="medium"
                @user={{ub.user}}
              >
                <div class="granted-on">
                  {{trustHTML
                    (i18n "badges.granted_on" date=(dFormatDate ub.granted_at))
                  }}
                </div>

                {{#if ub.post_number}}
                  <a
                    class="post-link"
                    href="{{ub.topic.url}}/{{ub.post_number}}"
                  >{{trustHTML ub.topic.fancyTitle}}</a>
                {{/if}}
              </DUserInfo>
            {{/each}}
          </div>
        </DLoadMore>

        {{#unless @controller.canLoadMore}}
          {{#if @controller.canShowOthers}}
            <div>
              <a
                class="btn btn-default"
                href={{@controller.model.url}}
                id="show-others-with-badge-link"
              >{{i18n "badges.others_count" count=@controller.othersCount}}</a>
            </div>
          {{/if}}
        {{/unless}}
      </div>

      <DConditionalLoadingSpinner @condition={{@controller.canLoadMore}} />
    {{/if}}
  </div>
</template>
