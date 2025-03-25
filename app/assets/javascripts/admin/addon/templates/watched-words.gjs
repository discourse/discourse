import RouteTemplate from 'ember-route-template'
import DPageHeader from "discourse/components/d-page-header";
import i18n from "discourse/helpers/i18n";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { LinkTo } from "@ember/routing";
export default RouteTemplate(<template><DPageHeader @titleLabel={{i18n "admin.config.watched_words.title"}} @descriptionLabel={{i18n "admin.config.watched_words.header_description"}} @learnMoreUrl="https://meta.discourse.org/t/241735" @hideTabs={{true}}>
  <:breadcrumbs>
    <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    <DBreadcrumbsItem @path="/admin/customize/watched_words" @label={{i18n "admin.config.watched_words.title"}} />
  </:breadcrumbs>
</DPageHeader>

<div class="admin-contents">
  <div class="admin-controls">
    <div class="controls">
      <div class="inline-form">
        <DButton @action={{@controller.toggleMenu}} @icon="bars" class="menu-toggle" />
        <TextField @value={{@controller.filter}} @placeholderKey="admin.watched_words.search" class="no-blur" />
        <DButton @action={{@controller.clearFilter}} @label="admin.watched_words.clear_filter" />
      </div>
    </div>
  </div>

  <div class="admin-nav pull-left">
    <ul class="nav nav-stacked">
      {{#each @controller.model as |action|}}
        <li class={{action.nameKey}}>
          <LinkTo @route="adminWatchedWords.action" @model={{action.nameKey}}>
            {{action.name}}
            {{#if action.words}}<span class="count">({{action.words.length}})</span>{{/if}}
          </LinkTo>
        </li>
      {{/each}}
    </ul>
  </div>

  <div class="admin-detail pull-left mobile-closed watched-words-detail">
    {{outlet}}
  </div>

  <div class="clearfix"></div>
</div></template>)