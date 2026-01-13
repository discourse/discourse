import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";

/*
 * Dev Tools Test Blocks (existing)
 */

@block("theme:dev-tools-test:dev-tools-test-block", {
  args: { title: { type: "string" } },
})
export class TestBlock extends Component {
  <template>
    <div class="dev-tools-test-block">{{@title}}</div>
  </template>
}

@block("theme:dev-tools-test:dev-tools-conditional-block")
export class ConditionalBlock extends Component {
  <template>
    <div class="dev-tools-conditional-block">Admin Only</div>
  </template>
}

/*
 * User Condition Test Blocks
 */

@block("theme:dev-tools-test:user-logged-in-block")
export class UserLoggedInBlock extends Component {
  <template>
    <div class="block-user-logged-in">Logged In User Content</div>
  </template>
}

@block("theme:dev-tools-test:user-admin-block")
export class UserAdminBlock extends Component {
  <template>
    <div class="block-user-admin">Admin Only Content</div>
  </template>
}

@block("theme:dev-tools-test:user-moderator-block")
export class UserModeratorBlock extends Component {
  <template>
    <div class="block-user-moderator">Moderator Content</div>
  </template>
}

@block("theme:dev-tools-test:user-trust-level-2-block")
export class UserTrustLevel2Block extends Component {
  <template>
    <div class="block-user-trust-level-2">Trust Level 2+ Content</div>
  </template>
}

/*
 * Route Condition Test Blocks
 */

@block("theme:dev-tools-test:route-category-block")
export class RouteCategoryBlock extends Component {
  <template>
    <div class="block-route-category">Category Page Content</div>
  </template>
}

@block("theme:dev-tools-test:route-topic-block")
export class RouteTopicBlock extends Component {
  <template>
    <div class="block-route-topic">Topic Page Content</div>
  </template>
}

@block("theme:dev-tools-test:route-discovery-block")
export class RouteDiscoveryBlock extends Component {
  <template>
    <div class="block-route-discovery">Discovery Page Content</div>
  </template>
}

/*
 * Setting Condition Test Blocks
 */

@block("theme:dev-tools-test:setting-badges-enabled-block")
export class SettingBadgesEnabledBlock extends Component {
  <template>
    <div class="block-setting-badges-enabled">Badges Enabled Content</div>
  </template>
}

/*
 * Combined Condition Test Blocks
 */

@block("theme:dev-tools-test:combined-logged-in-tl1-block")
export class CombinedLoggedInTL1Block extends Component {
  <template>
    <div class="block-combined-logged-in-tl1">Logged In + TL1 Content</div>
  </template>
}

@block("theme:dev-tools-test:combined-admin-category-block")
export class CombinedAdminCategoryBlock extends Component {
  <template>
    <div class="block-combined-admin-category">Admin on Category Page</div>
  </template>
}

/*
 * OR Condition Test Block
 */

@block("theme:dev-tools-test:or-admin-or-moderator-block")
export class OrAdminOrModeratorBlock extends Component {
  <template>
    <div class="block-or-admin-or-moderator">Admin OR Moderator Content</div>
  </template>
}

/*
 * Block Ordering Test Blocks
 */

@block("theme:dev-tools-test:order-first-block")
export class OrderFirstBlock extends Component {
  <template>
    <div class="block-order-first" data-order="1">First Block</div>
  </template>
}

@block("theme:dev-tools-test:order-second-block")
export class OrderSecondBlock extends Component {
  <template>
    <div class="block-order-second" data-order="2">Second Block</div>
  </template>
}

@block("theme:dev-tools-test:order-third-block")
export class OrderThirdBlock extends Component {
  <template>
    <div class="block-order-third" data-order="3">Third Block</div>
  </template>
}

@block("theme:dev-tools-test:order-fourth-block")
export class OrderFourthBlock extends Component {
  <template>
    <div class="block-order-fourth" data-order="4">Fourth Block</div>
  </template>
}

@block("theme:dev-tools-test:order-fifth-block")
export class OrderFifthBlock extends Component {
  <template>
    <div class="block-order-fifth" data-order="5">Fifth Block</div>
  </template>
}

/*
 * Viewport Condition Test Blocks
 */

@block("theme:dev-tools-test:viewport-mobile-block")
export class ViewportMobileBlock extends Component {
  <template>
    <div class="block-viewport-mobile">Mobile Only Content</div>
  </template>
}

@block("theme:dev-tools-test:viewport-desktop-block")
export class ViewportDesktopBlock extends Component {
  <template>
    <div class="block-viewport-desktop">Desktop Only Content</div>
  </template>
}

/*
 * Debug Tools Test Blocks (enhanced)
 */

@block("theme:dev-tools-test:debug-args-block", {
  args: {
    title: { type: "string", required: true },
    count: { type: "number", default: 0 },
    enabled: { type: "boolean", default: true },
  },
})
export class DebugArgsBlock extends Component {
  <template>
    <div class="block-debug-args">
      <span class="title">{{@title}}</span>
      <span class="count">{{@count}}</span>
      <span class="enabled">{{if @enabled "yes" "no"}}</span>
    </div>
  </template>
}

@block("theme:dev-tools-test:debug-conditions-block")
export class DebugConditionsBlock extends Component {
  <template>
    <div class="block-debug-conditions">Admin + TL2 Content</div>
  </template>
}

/*
 * Nested Ghost Block Test - leaf block for deep nesting test
 */

@block("theme:dev-tools-test:nested-ghost-leaf-block")
export class NestedGhostLeafBlock extends Component {
  <template>
    <div class="block-nested-ghost-leaf">Deeply Nested Content</div>
  </template>
}

/**
 * Pre-initializer that registers all test blocks.
 * Runs before "freeze-block-registry" to ensure blocks are available
 * before the registry is frozen.
 */
export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
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
      api.registerBlock(NestedGhostLeafBlock);
    });
  },
};
