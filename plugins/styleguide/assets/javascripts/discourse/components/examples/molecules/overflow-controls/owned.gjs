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
];

export default <template>
  <div class="styleguide-overflow-controls --narrow">
    <DOverflowControls @axis="horizontal" @ownedScroller={{true}} as |strip|>
      <ul
        class="styleguide-overflow-controls__list"
        aria-label="Owned scroller"
        {{strip.scroller}}
      >
        {{#each SECTIONS as |section|}}
          <li class="styleguide-overflow-controls__chip">{{section}}</li>
        {{/each}}
      </ul>
    </DOverflowControls>
  </div>
</template>
