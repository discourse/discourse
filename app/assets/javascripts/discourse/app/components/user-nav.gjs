import { hash } from "@ember/helper";
import DNavigationItem from "discourse/components/d-navigation-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
import and from "truth-helpers/helpers/and";
<template><section class="user-navigation user-navigation-primary">
  <HorizontalOverflowNav @ariaLabel="User primary" class="main-nav nav user-nav">
    {{#unless @user.profile_hidden}}
      <DNavigationItem @route="user.summary" class="user-nav__summary">
        {{dIcon "user"}}
        <span>{{iN "user.summary.title"}}</span>
      </DNavigationItem>

      {{#if @showActivityTab}}
        <DNavigationItem @route="userActivity" @ariaCurrentContext="parentNav" class="user-nav__activity">
          {{dIcon "bars-staggered"}}
          <span>{{iN "user.activity_stream"}}</span>
        </DNavigationItem>
      {{/if}}
    {{/unless}}

    {{#if @showNotificationsTab}}
      <DNavigationItem @route="userNotifications" @ariaCurrentContext="parentNav" class="user-nav__notifications">
        {{dIcon "bell" class="glyph"}}
        <span>{{iN "user.notifications"}}</span>
      </DNavigationItem>
    {{/if}}

    {{#if @showPrivateMessages}}
      <DNavigationItem @route="userPrivateMessages" @ariaCurrentContext="parentNav" class="user-nav__personal-messages">
        {{dIcon "envelope"}}
        <span>{{iN "user.private_messages"}}</span>
      </DNavigationItem>
    {{/if}}

    {{#if @canInviteToForum}}
      <DNavigationItem @route="userInvited" @ariaCurrentContext="parentNav" class="user-nav__invites">
        {{dIcon "user-plus"}}
        <span>{{iN "user.invited.title"}}</span>
      </DNavigationItem>
    {{/if}}

    {{#if @showBadges}}
      <DNavigationItem @route="user.badges" class="user-nav__badges">
        {{dIcon "certificate"}}
        <span>{{iN "badges.title"}}</span>
      </DNavigationItem>
    {{/if}}

    <PluginOutlet @name="user-main-nav" @connectorTagName="li" @outletArgs={{hash model=@user}} />

    {{#if @user.can_edit}}
      <DNavigationItem @route="preferences" @ariaCurrentContext="parentNav" class="user-nav__preferences">
        {{dIcon "gear"}}
        <span>{{iN "user.preferences.title"}}</span>
      </DNavigationItem>
    {{/if}}
    {{#if (and @isMobileView @isStaff)}}
      <li class="user-nav__admin">
        <a href={{@user.adminPath}}>
          {{dIcon "wrench"}}
          <span>{{iN "admin.user.manage_user"}}</span>
        </a>
      </li>
    {{/if}}
  </HorizontalOverflowNav>
</section></template>