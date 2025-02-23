{{#if (or this.loading this.groups.canLoadMore)}}
  {{hide-application-footer}}
{{/if}}

{{body-class "groups-page"}}

<PluginOutlet @name="before-groups-index-container" @connectorTagName="div" />

<section class="container groups-index">
  <div class="groups-header">
    {{#if this.currentUser.can_create_group}}
      <DButton
        @action={{this.new}}
        @icon="plus"
        @label="admin.groups.new.title"
        class="btn-default groups-header-new pull-right"
      />
    {{/if}}

    <div class="groups-header-filters">
      <Input
        @value={{readonly this.filter}}
        placeholder={{i18n "groups.index.all"}}
        class="groups-header-filters-name no-blur"
        {{on "input" (with-event-value this.onFilterChanged)}}
        @type="search"
        aria-description={{i18n "groups.index.search_results"}}
      />

      <ComboBox
        @value={{this.type}}
        @content={{this.types}}
        @onChange={{fn (mut this.type)}}
        @options={{hash clearable=true none="groups.index.filter"}}
        class="groups-header-filters-type"
      />
    </div>
  </div>

  {{#if this.groups}}
    <LoadMore
      @selector=".groups-boxes .group-box"
      @action={{action "loadMore"}}
    >
      <div class="container">
        <div class="groups-boxes">
          {{#each this.groups as |group|}}
            <LinkTo
              @route="group.members"
              @model={{group.name}}
              class="group-box"
              data-group-name={{group.name}}
            >
              <div class="group-box-inner">
                <div class="group-info-wrapper">
                  {{#if group.flair_url}}
                    <span class="group-avatar-flair">
                      <AvatarFlair
                        @flairName={{group.name}}
                        @flairUrl={{group.flair_url}}
                        @flairBgColor={{group.flair_bg_color}}
                        @flairColor={{group.flair_color}}
                      />
                    </span>
                  {{/if}}

                  <span class="group-info">
                    <GroupInfo @group={{group}} />
                    <div class="group-user-count">{{d-icon
                        "user"
                      }}{{group.user_count}}</div>
                  </span>
                </div>

                <div class="group-description">{{html-safe
                    group.bio_excerpt
                  }}</div>

                <div class="group-membership">
                  <GroupMembershipButton
                    @tagName=""
                    @model={{group}}
                    @showLogin={{route-action "showLogin"}}
                  >
                    {{#if group.is_group_owner}}
                      <span class="is-group-owner">
                        {{d-icon "shield-halved"}}
                        {{i18n "groups.index.is_group_owner"}}
                      </span>
                    {{else if group.is_group_user}}
                      <span class="is-group-member">
                        {{d-icon "check"}}
                        {{i18n "groups.index.is_group_user"}}
                      </span>
                    {{else if group.public_admission}}
                      {{i18n "groups.index.public"}}
                    {{else if group.isPrivate}}
                      {{d-icon "far-eye-slash"}}
                      {{i18n "groups.index.private"}}
                    {{else}}
                      {{#if group.automatic}}
                        {{i18n "groups.index.automatic"}}
                      {{else}}
                        {{d-icon "ban"}}
                        {{i18n "groups.index.closed"}}
                      {{/if}}
                    {{/if}}
                  </GroupMembershipButton>

                  <span>
                    <PluginOutlet
                      @name="group-index-box-after"
                      @connectorTagName="div"
                      @outletArgs={{hash model=group}}
                    />
                  </span>
                </div>
              </div>
            </LinkTo>
          {{/each}}
        </div>
      </div>
    </LoadMore>
    <ConditionalLoadingSpinner @condition={{this.groups.loadingMore}} />
  {{else}}
    <p role="status">{{i18n "groups.index.empty"}}</p>
  {{/if}}
</section>

<PluginOutlet @name="after-groups-index-container" @connectorTagName="div" />