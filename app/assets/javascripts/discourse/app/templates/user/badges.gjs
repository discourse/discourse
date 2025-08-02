import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import BadgeCard from "discourse/components/badge-card";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "user-badges-page"}}

    <section class="user-content" id="user-content">
      <PluginOutlet
        @name="user-badges-content"
        @outletArgs={{lazyHash
          sortedBadges=@controller.sortedBadges
          maxFavBadges=@controller.siteSettings.max_favorite_badges
          favoriteBadges=@controller.favoriteBadges
          canFavoriteMoreBadges=@controller.canFavoriteMoreBadges
          favorite=@controller.favorite
        }}
      >
        {{#if @controller.siteSettings.max_favorite_badges}}
          <p class="favorite-count">
            {{i18n
              "badges.favorite_count"
              count=@controller.favoriteBadges.length
              max=@controller.siteSettings.max_favorite_badges
            }}
          </p>
        {{/if}}

        <div class="badge-group-list">
          {{#each @controller.sortedBadges as |ub|}}
            <BadgeCard
              @badge={{ub.badge}}
              @count={{ub.count}}
              @canFavorite={{ub.can_favorite}}
              @isFavorite={{ub.is_favorite}}
              @username={{@controller.username}}
              @canFavoriteMoreBadges={{@controller.canFavoriteMoreBadges}}
              @onFavoriteClick={{fn @controller.favorite ub}}
              @filterUser="true"
            />
          {{/each}}
          <PluginOutlet
            @name="after-user-profile-badges"
            @outletArgs={{lazyHash user=@controller.user.model}}
          />
        </div>
      </PluginOutlet>
    </section>
  </template>
);
