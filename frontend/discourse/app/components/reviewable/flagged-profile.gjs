import ReviewableField from "discourse/components/reviewable-field";
import { i18n } from "discourse-i18n";

export default <template>
  {{#let @reviewable.payload as |profile|}}
    <div class="review-item__meta-content">
      <div class="reviewable-user-info">
        <div class="reviewable-user-fields">
          <ReviewableField
            @classes="reviewable-user-details username"
            @name={{i18n "review.user.username"}}
            @value={{profile.username}}
            as |username|
          >
            {{#if @reviewable.target_url}}
              <a href={{@reviewable.target_url}}>{{username}}</a>
            {{else}}
              {{username}}
            {{/if}}
          </ReviewableField>
          <ReviewableField
            @classes="reviewable-user-details avatar"
            @name={{i18n "review.user.avatar"}}
            @value={{profile.avatar_url}}
            as |url|
          >
            <img
              alt=""
              class="reviewable-user-avatar"
              loading="lazy"
              src={{url}}
            />
          </ReviewableField>
          <ReviewableField
            @classes="reviewable-user-details profile-header"
            @name={{i18n "review.user.profile_header"}}
            @value={{profile.profile_header_url}}
            as |url|
          >
            <a href={{url}}>{{i18n "review.view_image"}}</a>
          </ReviewableField>
          <ReviewableField
            @classes="reviewable-user-details card-background"
            @name={{i18n "review.user.card_background"}}
            @value={{profile.card_background_url}}
            as |url|
          >
            <a href={{url}}>{{i18n "review.view_image"}}</a>
          </ReviewableField>
          <ReviewableField
            @classes="reviewable-user-details name"
            @name={{i18n "review.user.name"}}
            @value={{profile.name}}
          />
          <ReviewableField
            @classes="reviewable-user-details title"
            @name={{i18n "user.title.title"}}
            @value={{profile.title}}
          />
          <ReviewableField
            @classes="reviewable-user-details bio"
            @name={{i18n "review.user.bio"}}
            @value={{profile.bio}}
          />
          <ReviewableField
            @classes="reviewable-user-details location"
            @name={{i18n "user.location"}}
            @value={{profile.location}}
          />
          <ReviewableField
            @classes="reviewable-user-details website"
            @name={{i18n "review.user.website"}}
            @value={{profile.website}}
          />
          {{#each profile.profile_fields as |field|}}
            <ReviewableField
              @classes="reviewable-user-details user-field"
              @name={{field.name}}
              @value={{field.value}}
            />
          {{/each}}
        </div>
      </div>
    </div>
  {{/let}}
</template>
