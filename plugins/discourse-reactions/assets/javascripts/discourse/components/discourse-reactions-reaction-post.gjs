import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { service } from "@ember/service";
import UserStreamItem from "discourse/components/user-stream-item";
import avatar from "discourse/helpers/avatar";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { emojiUrlFor } from "discourse/lib/text";

let cachedNames = new Map();
let pendingSearch = null;

export default class DiscourseReactionsReactionPost extends Component {
  @service site;
  @service siteSettings;

  @tracked updatedExcerpt = this.args.reaction.post.excerpt;
  @tracked updatedExpandedExcerpt = this.args.reaction.post.expandedExcerpt;

  @equal("args.reaction.post.post_type", "site.post_types.moderator_action")
  moderatorAction;

  constructor() {
    super(...arguments);
    this.updateMentionedUsernames();
  }

  @action
  async updateMentionedUsernames() {
    this.updatedExcerpt = await this.replaceMentionsWithFullNames(
      this.args.reaction.post.excerpt
    );
    this.updatedExpandedExcerpt = await this.replaceMentionsWithFullNames(
      this.args.reaction.post.expandedExcerpt
    );
  }

  async replaceMentionsWithFullNames(text) {
    if (!text) {
      return text;
    }

    const mentionRegex = /@([\p{L}\d._]+)/gu;

    const replacedText = await Promise.all(
      text.split(mentionRegex).map(async (part, index) => {
        if (index % 2 === 1) {
          const fullName = await this.searchUsername(part);
          return `@${fullName || part}`;
        }
        return part;
      })
    );

    return replacedText.join("");
  }

  async searchUsername(username) {
    username = username.toLowerCase();

    if (cachedNames.has(username)) {
      return cachedNames.get(username);
    }

    if (pendingSearch?.usernames.size <= 50) {
      pendingSearch.usernames.add(username);
      const results = await pendingSearch.search;

      if (results.searchedUsernames.includes(username)) {
        const fullName =
          results.data.users?.find(
            (user) => user.username.toLowerCase() === username
          )?.name ||
          results.data.groups?.find(
            (group) => group.name.toLowerCase() === username
          )?.full_name;

        cachedNames.set(username, fullName);
        return fullName;
      }
    }

    return this.deferSearch(username);
  }

  async deferSearch(username) {
    const usernamesList = new Set([username]);

    pendingSearch = {
      search: new Promise((resolve) => {
        setTimeout(async () => {
          const searchedUsernames = Array.from(usernamesList);
          pendingSearch = null;

          const data = await ajax("/u/search/users.json", {
            data: {
              usernames: searchedUsernames.join(","),
              include_groups: this.siteSettings.show_fullname_for_groups,
            },
          });

          resolve({ searchedUsernames, data });
        }, 20);
      }),
      usernames: usernamesList,
    };

    return this.searchUsername(username);
  }

  get postUrl() {
    return getURL(this.args.reaction.post.url);
  }

  get emojiUrl() {
    const reactionValue = this.args.reaction.reaction.reaction_value;
    return reactionValue ? emojiUrlFor(reactionValue) : null;
  }

  <template>
    <UserStreamItem
      @item={{hash
        username=@reaction.post_user.username
        name=@reaction.post_user.name
        avatar_template=@reaction.post_user.avatar_template
        created_at=@reaction.created_at
        postUrl=this.postUrl
        category=@reaction.category
        title=@reaction.topic.title
        expandedExcerpt=this.updatedExpandedExcerpt
        excerpt=this.updatedExcerpt
        topic_id=@reaction.topic_id
        post_id=@reaction.post_id
        user_id=@reaction.user_id
      }}
    >
      <:bottom>
        {{#if @reaction.reaction.reaction_users_count}}
          <div class="discourse-reactions-my-reaction">
            <img src={{this.emojiUrl}} class="reaction-emoji" />
            <a
              href={{@reaction.user.userUrl}}
              data-user-card={{@reaction.user.username}}
              class="avatar-link"
            >
              {{avatar
                @reaction.user
                imageSize="tiny"
                extraClasses="actor"
                ignoreTitle="true"
              }}
            </a>
          </div>
        {{/if}}
      </:bottom>
    </UserStreamItem>
  </template>
}
