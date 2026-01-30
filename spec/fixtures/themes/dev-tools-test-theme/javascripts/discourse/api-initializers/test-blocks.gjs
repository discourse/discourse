import { apiInitializer } from "discourse/lib/api";
import BlockGroup from "discourse/blocks/builtin/block-group";
import {
  CombinedAdminCategoryBlock,
  CombinedLoggedInTL1Block,
  ConditionalBlock,
  DebugArgsBlock,
  DebugConditionsBlock,
  NestedGhostLeafBlock,
  OrAdminOrModeratorBlock,
  OrderFifthBlock,
  OrderFirstBlock,
  OrderFourthBlock,
  OrderSecondBlock,
  OrderThirdBlock,
  RouteCategoryBlock,
  RouteDiscoveryBlock,
  RouteTopicBlock,
  SettingBadgesEnabledBlock,
  TestBlock,
  UserAdminBlock,
  UserLoggedInBlock,
  UserModeratorBlock,
  UserTrustLevel2Block,
  ViewportDesktopBlock,
  ViewportMobileBlock,
} from "../pre-initializers/register-test-blocks";

export default apiInitializer((api) => {
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
      conditions: [{ type: "route", pages: ["CATEGORY_PAGES"] }],
    },
    {
      block: RouteTopicBlock,
      conditions: [{ type: "route", urls: ["/t/**"] }],
    },
    {
      block: RouteDiscoveryBlock,
      conditions: [{ type: "route", pages: ["DISCOVERY_PAGES"] }],
    },

    // Setting condition blocks
    {
      block: SettingBadgesEnabledBlock,
      conditions: [{ type: "setting", name: "enable_badges", enabled: true }],
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
        { type: "route", pages: ["CATEGORY_PAGES"] },
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

    // Nested ghost blocks test - 4 levels deep with all children having failing conditions
    // This tests that ghost blocks are shown for container blocks when all children are hidden
    {
      block: BlockGroup,
      args: { name: "level-1" },
      classNames: "deep-ghosts",
      children: [
        {
          block: BlockGroup,
          args: { name: "level-2" },
          children: [
            {
              block: BlockGroup,
              args: { name: "level-3" },
              children: [
                {
                  block: BlockGroup,
                  args: { name: "level-4" },
                  children: [
                    {
                      block: NestedGhostLeafBlock,
                      conditions: [{ type: "user", admin: true }],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  ]);
});
