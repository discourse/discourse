import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { number } from "discourse/lib/formatter";
import type Category from "discourse/models/category";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import DUserAvatar, {
  type DUserAvatarUser,
} from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import { i18n } from "discourse-i18n";

interface CategoryLeaderboardSignature {
  Args: {
    outletArgs?: { category?: Category };
  };
}

interface RankedContributor extends DUserAvatarUser {
  likes_received: number;
}

@block("category-leaderboard", {
  description:
    "Users ranked by likes received in the category passed to the outlet",
})
export default class CategoryLeaderboard extends Component<CategoryLeaderboardSignature> {
  @bind
  async fetchUsers(categoryId: unknown) {
    if (typeof categoryId !== "number") {
      return null;
    }

    const { users } = await ajax<{ users: RankedContributor[] }>(
      `/c/${categoryId}/leaderboard.json`
    );
    return users.length ? users : null;
  }

  <template>
    {{#if @outletArgs.category}}
      <section class="context-category__block">
        <h3>{{i18n "page_shell.category_leaderboard"}}</h3>
        <DAsyncContent
          @asyncData={{this.fetchUsers}}
          @context={{@outletArgs.category.id}}
        >
          <:loading><DSkeleton @count={{5}} /></:loading>
          <:content as |users|>
            <ol class="context-category__contributors">
              {{#each users as |user|}}
                <li>
                  <DUserAvatar @size="small" @user={{user}} />
                  <DUserLink
                    class="context-category__contributor-name"
                    @user={{user}}
                  >
                    {{user.username}}
                  </DUserLink>
                  <span class="context-category__likes">
                    {{i18n
                      "page_shell.category_likes_received"
                      count=user.likes_received
                      number=(number user.likes_received)
                    }}
                  </span>
                </li>
              {{/each}}
            </ol>
          </:content>
          <:empty><p>{{i18n
                "page_shell.category_leaderboard_empty"
              }}</p></:empty>
        </DAsyncContent>
      </section>
    {{/if}}
  </template>
}
