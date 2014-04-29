/**
  This controller supports displaying static content.

  @class StaticController
  @extends Em.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController = Em.ObjectController.extend({
  showLoginButton: Em.computed.equal('path', 'login')
});

Discourse.StaticController.reopenClass({
  PAGES: ['faq', 'tos', 'privacy', 'login'],
  CONFIGS: {
    'faq': 'faq_url',
    'tos': 'tos_url',
    'privacy': 'privacy_policy_url'
  }
});
