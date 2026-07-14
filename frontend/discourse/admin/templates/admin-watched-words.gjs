import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import AdminWatchedWordsActionNav from "discourse/admin/components/admin-watched-words-action-nav";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.watched_words.title"}}
    @descriptionLabel={{i18n "admin.config.watched_words.header_description"}}
    @learnMoreUrl="https://meta.discourse.org/t/241735"
    @hideTabs={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/customize/watched_words"
        @label={{i18n "admin.config.watched_words.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-contents">
    <div class="admin-controls">
      <div class="controls">
        <div class="inline-form">
          {{#if @controller.showMenuToggle}}
            <DButton
              @action={{@controller.toggleMenu}}
              @icon="bars"
              class="btn-default menu-toggle"
              {{didInsert @controller.registerMenuTrigger}}
            />
          {{/if}}
          <DTextField
            @value={{@controller.filter}}
            @placeholderKey="admin.watched_words.search"
            class="no-blur"
          />
          <DButton
            @action={{@controller.clearFilter}}
            @label="admin.watched_words.clear_filter"
            class="btn-default"
          />
        </div>
      </div>
    </div>

    <div
      class="admin-nav pull-left"
      {{didInsert @controller.subscribe}}
      {{willDestroy @controller.unsubscribe}}
    >
      <AdminWatchedWordsActionNav @items={{@controller.filteredWatchedWords}} />
    </div>

    <div class="admin-detail pull-left watched-words-detail">
      {{outlet}}
    </div>

    <div class="clearfix"></div>
  </div>
</template>
