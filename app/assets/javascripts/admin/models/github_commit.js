/**
  A model for a git commit to the discourse repo, fetched from the github.com api.

  @class GithubCommit
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.GithubCommit = Discourse.Model.extend({
  gravatarUrl: function(){
    if( this.get('author') && this.get('author.gravatar_id') ){
      return("https://www.gravatar.com/avatar/" + this.get('author.gravatar_id') + ".png?s=38&r=pg&d=identicon");
    } else {
      return "https://www.gravatar.com/avatar/b30fff48d257cdd17c4437afac19fd30.png?s=38&r=pg&d=identicon";
    }
  }.property("commit"),

  commitUrl: function(){
    return("https://github.com/discourse/discourse/commit/" + this.get('sha'));
  }.property("sha"),

  timeAgo: function() {
    return moment(this.get('commit.committer.date')).relativeAge({format: 'medium', leaveAgo: true});
  }.property("commit.committer.date")
});

Discourse.GithubCommit.reopenClass({
  findAll: function() {
    var result = Em.A();
    Discourse.ajax( "https://api.github.com/repos/discourse/discourse/commits?callback=callback", {
      dataType: 'jsonp',
      type: 'get',
      data: { per_page: 40 }
    }).then(function (response) {
      _.each(response.data,function(commit) {
        result.pushObject( Discourse.GithubCommit.create(commit) );
      });
    });
    return result;
  }
});
