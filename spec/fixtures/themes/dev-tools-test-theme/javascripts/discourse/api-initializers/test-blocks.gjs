import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";
import { apiInitializer } from "discourse/lib/api";

/*
 * Dev Tools Test Blocks (existing)
 */

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

/*
 * User Condition Test Blocks
 */

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

/*
 * Route Condition Test Blocks
 */

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

/*
 * Setting Condition Test Blocks
 */

@block("setting-badges-enabled-block")
class SettingBadgesEnabledBlock extends Component {
  <template>
    <div class="block-setting-badges-enabled">Badges Enabled Content</div>
  </template>
}

/*
 * Combined Condition Test Blocks
 */

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

/*
 * OR Condition Test Block
 */

@block("or-admin-or-moderator-block")
class OrAdminOrModeratorBlock extends Component {
  <template>
    <div class="block-or-admin-or-moderator">Admin OR Moderator Content</div>
  </template>
}

/*
 * Block Ordering Test Blocks
 */

@block("order-first-block")
class OrderFirstBlock extends Component {
  <template>
    <div class="block-order-first" data-order="1">First Block</div>
  </template>
}

@block("order-second-block")
class OrderSecondBlock extends Component {
  <template>
    <div class="block-order-second" data-order="2">Second Block</div>
  </template>
}

@block("order-third-block")
class OrderThirdBlock extends Component {
  <template>
    <div class="block-order-third" data-order="3">Third Block</div>
  </template>
}

@block("order-fourth-block")
class OrderFourthBlock extends Component {
  <template>
    <div class="block-order-fourth" data-order="4">Fourth Block</div>
  </template>
}

@block("order-fifth-block")
class OrderFifthBlock extends Component {
  <template>
    <div class="block-order-fifth" data-order="5">Fifth Block</div>
  </template>
}

/*
 * Viewport Condition Test Blocks
 */

@block("viewport-mobile-block")
class ViewportMobileBlock extends Component {
  <template>
    <div class="block-viewport-mobile">Mobile Only Content</div>
  </template>
}

@block("viewport-desktop-block")
class ViewportDesktopBlock extends Component {
  <template>
    <div class="block-viewport-desktop">Desktop Only Content</div>
  </template>
}

/*
 * Debug Tools Test Blocks (enhanced)
 */

@block("debug-args-block", {
  args: {
    title: { type: "string", required: true },
    count: { type: "number", default: 0 },
    enabled: { type: "boolean", default: true },
  },
})
class DebugArgsBlock extends Component {
  <template>
    <div class="block-debug-args">
      <span class="title">{{@title}}</span>
      <span class="count">{{@count}}</span>
      <span class="enabled">{{if @enabled "yes" "no"}}</span>
    </div>
  </template>
}

@block("debug-conditions-block")
class DebugConditionsBlock extends Component {
  <template>
    <div class="block-debug-conditions">Admin + TL2 Content</div>
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
  api.registerBlock(OrderFirstBlock);
  api.registerBlock(OrderSecondBlock);
  api.registerBlock(OrderThirdBlock);
  api.registerBlock(OrderFourthBlock);
  api.registerBlock(OrderFifthBlock);
  api.registerBlock(ViewportMobileBlock);
  api.registerBlock(ViewportDesktopBlock);
  api.registerBlock(DebugArgsBlock);
  api.registerBlock(DebugConditionsBlock);

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
      conditions: [{ type: "route", urls: ["$CATEGORY_PAGES"] }],
    },
    {
      block: RouteTopicBlock,
      conditions: [{ type: "route", urls: ["/t/**"] }],
    },
    {
      block: RouteDiscoveryBlock,
      conditions: [{ type: "route", urls: ["$DISCOVERY_PAGES"] }],
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
        { type: "route", urls: ["$CATEGORY_PAGES"] },
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

    // Block ordering blocks (in specific order)
    { block: OrderFirstBlock },
    { block: OrderSecondBlock },
    { block: OrderThirdBlock },
    { block: OrderFourthBlock },
    { block: OrderFifthBlock },

    // Viewport condition blocks
    {
      block: ViewportMobileBlock,
      conditions: [{ type: "viewport", max: "sm" }],
    },
    {
      block: ViewportDesktopBlock,
      conditions: [{ type: "viewport", min: "lg" }],
    },

    // Debug tools test blocks
    {
      block: DebugArgsBlock,
      args: { title: "Debug Title", count: 42, enabled: true },
    },
    {
      block: DebugConditionsBlock,
      conditions: [
        { type: "user", admin: true },
        { type: "user", minTrustLevel: 2 },
      ],
    },
  ]);
});
