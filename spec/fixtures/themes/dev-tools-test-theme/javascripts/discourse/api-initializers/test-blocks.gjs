import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";
import { apiInitializer } from "discourse/lib/api";

// =============================================================================
// Dev Tools Test Blocks (existing)
// =============================================================================

@block("dev-tools-test-block", {
  args: { title: { type: "string" } },
})
class TestBlock extends Component {
  <template>
    <div class="dev-tools-test-block">{{@title}}</div>
  </template>
}

@block("dev-tools-conditional-block")
class ConditionalBlock extends Component {
  <template>
    <div class="dev-tools-conditional-block">Admin Only</div>
  </template>
}

// =============================================================================
// User Condition Test Blocks
// =============================================================================

@block("user-logged-in-block")
class UserLoggedInBlock extends Component {
  <template>
    <div class="block-user-logged-in">Logged In User Content</div>
  </template>
}

@block("user-admin-block")
class UserAdminBlock extends Component {
  <template>
    <div class="block-user-admin">Admin Only Content</div>
  </template>
}

@block("user-moderator-block")
class UserModeratorBlock extends Component {
  <template>
    <div class="block-user-moderator">Moderator Content</div>
  </template>
}

@block("user-trust-level-2-block")
class UserTrustLevel2Block extends Component {
  <template>
    <div class="block-user-trust-level-2">Trust Level 2+ Content</div>
  </template>
}

// =============================================================================
// Route Condition Test Blocks
// =============================================================================

@block("route-category-block")
class RouteCategoryBlock extends Component {
  <template>
    <div class="block-route-category">Category Page Content</div>
  </template>
}

@block("route-topic-block")
class RouteTopicBlock extends Component {
  <template>
    <div class="block-route-topic">Topic Page Content</div>
  </template>
}

@block("route-discovery-block")
class RouteDiscoveryBlock extends Component {
  <template>
    <div class="block-route-discovery">Discovery Page Content</div>
  </template>
}

// =============================================================================
// Setting Condition Test Blocks
// =============================================================================

@block("setting-badges-enabled-block")
class SettingBadgesEnabledBlock extends Component {
  <template>
    <div class="block-setting-badges-enabled">Badges Enabled Content</div>
  </template>
}

// =============================================================================
// Combined Condition Test Blocks
// =============================================================================

@block("combined-logged-in-tl1-block")
class CombinedLoggedInTL1Block extends Component {
  <template>
    <div class="block-combined-logged-in-tl1">Logged In + TL1 Content</div>
  </template>
}

@block("combined-admin-category-block")
class CombinedAdminCategoryBlock extends Component {
  <template>
    <div class="block-combined-admin-category">Admin on Category Page</div>
  </template>
}

// =============================================================================
// OR Condition Test Block
// =============================================================================

@block("or-admin-or-moderator-block")
class OrAdminOrModeratorBlock extends Component {
  <template>
    <div class="block-or-admin-or-moderator">Admin OR Moderator Content</div>
  </template>
}

export default apiInitializer((api) => {
  // Register all blocks
  api.registerBlock(TestBlock);
  api.registerBlock(ConditionalBlock);
  api.registerBlock(UserLoggedInBlock);
  api.registerBlock(UserAdminBlock);
  api.registerBlock(UserModeratorBlock);
  api.registerBlock(UserTrustLevel2Block);
  api.registerBlock(RouteCategoryBlock);
  api.registerBlock(RouteTopicBlock);
  api.registerBlock(RouteDiscoveryBlock);
  api.registerBlock(SettingBadgesEnabledBlock);
  api.registerBlock(CombinedLoggedInTL1Block);
  api.registerBlock(CombinedAdminCategoryBlock);
  api.registerBlock(OrAdminOrModeratorBlock);

  // Render blocks with conditions
  api.renderBlocks("hero-blocks", [
    // Dev tools test blocks (existing)
    { block: TestBlock, args: { title: "Test Title" } },
    { block: ConditionalBlock, conditions: [{ type: "user", admin: true }] },

    // User condition blocks
    {
      block: UserLoggedInBlock,
      conditions: [{ type: "user", loggedIn: true }],
    },
    {
      block: UserAdminBlock,
      conditions: [{ type: "user", admin: true }],
    },
    {
      block: UserModeratorBlock,
      conditions: [{ type: "user", moderator: true }],
    },
    {
      block: UserTrustLevel2Block,
      conditions: [{ type: "user", minTrustLevel: 2 }],
    },

    // Route condition blocks
    {
      block: RouteCategoryBlock,
      conditions: [{ type: "route", routes: ["discovery.category"] }],
    },
    {
      block: RouteTopicBlock,
      conditions: [{ type: "route", routes: ["topic.*"] }],
    },
    {
      block: RouteDiscoveryBlock,
      conditions: [{ type: "route", routes: ["discovery.*"] }],
    },

    // Setting condition blocks
    {
      block: SettingBadgesEnabledBlock,
      conditions: [{ type: "setting", setting: "enable_badges", enabled: true }],
    },

    // Combined condition blocks (AND logic)
    {
      block: CombinedLoggedInTL1Block,
      conditions: [
        { type: "user", loggedIn: true },
        { type: "user", minTrustLevel: 1 },
      ],
    },
    {
      block: CombinedAdminCategoryBlock,
      conditions: [
        { type: "user", admin: true },
        { type: "route", routes: ["discovery.category"] },
      ],
    },

    // OR condition block
    {
      block: OrAdminOrModeratorBlock,
      conditions: [
        {
          any: [{ type: "user", admin: true }, { type: "user", moderator: true }],
        },
      ],
    },
  ]);
});
