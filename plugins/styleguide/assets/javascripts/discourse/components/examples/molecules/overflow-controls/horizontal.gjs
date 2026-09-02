import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

const SECTIONS = [
  "Overview",
  "Activity",
  "Badges",
  "Notifications",
  "Messages",
  "Invites",
  "Preferences",
  "Security",
  "Groups",
  "Bookmarks",
  "Drafts",
  "Summary",
];

export default <template>
  <div
    class="styleguide-overflow-controls styleguide-overflow-controls--narrow"
  >
    <DOverflowControls @class="styleguide-overflow-controls__strip">
      {{#each SECTIONS as |section|}}
        <span class="styleguide-overflow-controls__chip">{{section}}</span>
      {{/each}}
    </DOverflowControls>
  </div>
</template>
