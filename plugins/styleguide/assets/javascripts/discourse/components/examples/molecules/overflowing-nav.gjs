import { eq } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

const SECTIONS = [
  "Summary",
  "Activity",
  "Notifications",
  "Messages",
  "Badges",
  "Invites",
  "Preferences",
  "Security",
  "Groups",
  "Bookmarks",
];

export default <template>
  <div class="styleguide-overflow-controls --narrow">
    <DHorizontalOverflowNav @ariaLabel="Overflowing sections">
      {{#each SECTIONS as |section index|}}
        <li>
          <a href="#" class={{if (eq index 6) "active"}}>{{section}}</a>
        </li>
      {{/each}}
    </DHorizontalOverflowNav>
  </div>
</template>
