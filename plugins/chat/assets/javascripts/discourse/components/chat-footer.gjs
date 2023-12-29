import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class ChatFooter extends Component {
  @service chat;
  @service router;
  @service chatStateManager;
  @service chatChannelsManager;
  @service site;
  @service siteSettings;
  @service session;
  @service currentUser;

<template>
  <nav class="c-footer">
    <DButton class="btn-flat c-footer__item --active" @icon="users" aria-label="Switch to DM list" @translatedLabel="DMs"/>
    <DButton class="btn-flat c-footer__item" @icon="comments" aria-label="Switch to channel list" @translatedLabel="Channels"/>
    <DButton class="btn-flat c-footer__item" @icon="discourse-threads" aria-label="Switch to my threads list" @translatedLabel="My Threads"/>
  </nav>
</template>
