{{#if this.canLoadMore}}
  {{hide-application-footer}}
{{/if}}

<div class="container show-badge {{this.model.slug}}">
  <h1>
    <LinkTo @route="badges.index">{{i18n "badges.title"}}</LinkTo>
    /
    {{this.model.name}}
  </h1>

  <div class="show-badge-details">
    <BadgeCard
      @badge={{this.model}}
      @size="large"
      @count={{this.userBadges.grant_count}}
    />
    <div class="badge-grant-info {{if this.hiddenSetTitle '' 'hidden'}}">
      <div>
        {{#if this.canSelectTitle}}
          <div class="grant-info-item">
            {{i18n "badges.allow_title"}}
            <DButton
              @action={{this.toggleSetUserTitle}}
              @icon="pencil"
              class="btn-default pad-left"
            />
          </div>
        {{/if}}
        {{#if this.model.multiple_grant}}
          <div class="grant-info-item">
            {{i18n "badges.multiple_grant"}}
          </div>
        {{/if}}
      </div>
    </div>

    {{#if this.canSelectTitle}}
      <div class="badge-set-title {{if this.hiddenSetTitle 'hidden' ''}}">
        <PluginOutlet
          @name="selectable-user-badges"
          @outletArgs={{hash
            selectableUserBadges=this.selectableUserBadges
            closeAction=this.toggleSetUserTitle
          }}
        >
          <BadgeTitle
            @selectableUserBadges={{this.selectableUserBadges}}
            @closeAction={{this.toggleSetUserTitle}}
          />
        </PluginOutlet>
      </div>
    {{/if}}
  </div>

  {{#if this.userBadges}}
    <div class="user-badges {{this.model.slug}}">
      <LoadMore @selector=".badge-info" @action={{action "loadMore"}}>
        <div class="badges-granted">
          {{#each this.userBadges as |ub|}}
            <UserInfo
              @user={{ub.user}}
              @size="medium"
              @date={{ub.granted_at}}
              class="badge-info"
            >
              <div class="granted-on">
                {{html-safe
                  (i18n "badges.granted_on" date=(format-date ub.granted_at))
                }}
              </div>

              {{#if ub.post_number}}
                <a
                  class="post-link"
                  href="{{ub.topic.url}}/{{ub.post_number}}"
                >{{html-safe ub.topic.fancyTitle}}</a>
              {{/if}}
            </UserInfo>
          {{/each}}
        </div>
      </LoadMore>

      {{#unless this.canLoadMore}}
        {{#if this.canShowOthers}}
          <div>
            <a
              id="show-others-with-badge-link"
              href={{this.model.url}}
              class="btn btn-default"
            >{{i18n "badges.others_count" count=this.othersCount}}</a>
          </div>
        {{/if}}
      {{/unless}}
    </div>

    <ConditionalLoadingSpinner @condition={{this.canLoadMore}} />
  {{/if}}
</div>