import { apiInitializer } from "discourse/lib/api";
import {
  CombinedAdminCategoryBlock,
  CombinedLoggedInTL1Block,
  ConditionalBlock,
  DebugArgsBlock,
  DebugConditionsBlock,
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
