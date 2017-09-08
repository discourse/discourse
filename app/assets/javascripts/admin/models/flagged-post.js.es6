import { ajax } from 'discourse/lib/ajax';
import AdminUser from 'admin/models/admin-user';
import Topic from 'discourse/models/topic';
import Post from 'discourse/models/post';
import { iconHTML } from 'discourse-common/lib/icon-library';
import computed from 'ember-addons/ember-computed-decorators';

const FlaggedPost = Post.extend({

  @computed
  summary() {
    return _(this.post_actions)
      .groupBy(function (a) { return a.post_action_type_id; })
      .map(function (v,k) { return I18n.t('admin.flags.summary.action_type_' + k, { count: v.length }); })
      .join(',');
  },

  @computed
  flaggers() {
    return this.post_actions.map(postAction => {
      return {
        user: this.userLookup[postAction.user_id],
        topic: this.topicLookup[postAction.topic_id],
        flagType: I18n.t('admin.flags.summary.action_type_' + postAction.post_action_type_id, { count: 1 }),
        flaggedAt: postAction.created_at,
        disposedBy: postAction.disposed_by_id ? this.userLookup[postAction.disposed_by_id] : null,
        disposedAt: postAction.disposed_at,
        dispositionIcon: this.dispositionIcon(postAction.disposition),
        tookAction: postAction.staff_took_action
      };
    });
  },

  dispositionIcon(disposition) {
    if (!disposition) { return null; }
    let icon;
    let title = 'admin.flags.dispositions.' + disposition;
    switch (disposition) {
      case "deferred": { icon = "external-link"; break; }
      case "agreed": { icon = "thumbs-o-up"; break; }
      case "disagreed": { icon = "thumbs-o-down"; break; }
    }
    return iconHTML(icon, { title });
  },

  @computed('last_revised_at', 'post_actions.@each.created_at')
  wasEdited(lastRevisedAt) {
    if (Ember.isEmpty(this.get("last_revised_at"))) { return false; }
    lastRevisedAt = Date.parse(lastRevisedAt);
    return _.some(this.get("post_actions"), function (postAction) {
      return Date.parse(postAction.created_at) < lastRevisedAt;
    });
  },

  @computed
  conversations() {
    let conversations = [];

    this.post_actions.forEach(postAction => {
      if (postAction.conversation) {
        let conversation = {
          permalink: postAction.permalink,
          hasMore: postAction.conversation.has_more,
          response: {
            excerpt: postAction.conversation.response.excerpt,
            user: this.userLookup[postAction.conversation.response.user_id]
          }
        };

        if (postAction.conversation.reply) {
          conversation.reply = {
            excerpt: postAction.conversation.reply.excerpt,
            user: this.userLookup[postAction.conversation.reply.user_id]
          };
        }
        conversations.push(conversation);
      }
    });

    return conversations;
  },

  @computed
  user() {
    return this.userLookup[this.user_id];
  },

  @computed
  topic() {
    return this.topicLookup[this.topic_id];
  },

  @computed('post_actions.@each.name_key')
  flaggedForSpam() {
    return !_.every(this.get('post_actions'), function(action) { return action.name_key !== 'spam'; });
  },

  @computed('post_actions.@each.targets_topic')
  topicFlagged() {
    return _.any(this.get('post_actions'), function(action) { return action.targets_topic; });
  },

  @computed('post_actions.@each.targets_topic')
  postAuthorFlagged() {
    return _.any(this.get('post_actions'), function(action) { return !action.targets_topic; });
  },

  @computed('flaggedForSpan')
  canDeleteAsSpammer(flaggedForSpam) {
    return Discourse.User.currentProp('staff') && flaggedForSpam && this.get('user.can_delete_all_posts') && this.get('user.can_be_deleted');
  },

  deletePost() {
    if (this.get('post_number') === 1) {
      return ajax('/t/' + this.topic_id, { type: 'DELETE', cache: false });
    } else {
      return ajax('/posts/' + this.id, { type: 'DELETE', cache: false });
    }
  },

  disagreeFlags() {
    return ajax('/admin/flags/disagree/' + this.id, { type: 'POST', cache: false });
  },

  deferFlags(deletePost) {
    return ajax('/admin/flags/defer/' + this.id, { type: 'POST', cache: false, data: { delete_post: deletePost } });
  },

  agreeFlags(actionOnPost) {
    return ajax('/admin/flags/agree/' + this.id, { type: 'POST', cache: false, data: { action_on_post: actionOnPost } });
  },

  postHidden: Ember.computed.alias('hidden'),

  @computed
  extraClasses() {
    let classes = [];
    if (this.get('hidden')) { classes.push('hidden-post'); }
    if (this.get('deleted')) { classes.push('deleted'); }
    return classes.join(' ');
  },

  deleted: Ember.computed.or('deleted_at', 'topic_deleted_at')
});

FlaggedPost.reopenClass({
  findAll(args) {
    let { filter } = args;

    let result = [];
    result.set('loading', true);

    let data = {};
    if (args.topic_id) {
      data.topic_id = args.topic_id;
    }
    if (args.offset) {
      data.offset = args.offset;
    }

    return ajax(`/admin/flags/${filter}.json`, { data }).then(response => {
      // users
      let userLookup = {};
      response.users.forEach(user => userLookup[user.id] = AdminUser.create(user));

      // topics
      let topicLookup = {};
      response.topics.forEach(topic => topicLookup[topic.id] = Topic.create(topic));

      // posts
      response.posts.forEach(post => {
        let f = FlaggedPost.create(post);
        f.userLookup = userLookup;
        f.topicLookup = topicLookup;
        result.pushObject(f);
      });

      result.set('loading', false);
      return result;
    });
  }
});

export default FlaggedPost;
