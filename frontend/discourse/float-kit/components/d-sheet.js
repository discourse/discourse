import ScrollContent from "./d-scroll/content";
import ScrollRoot from "./d-scroll/root";
import ScrollView from "./d-scroll/view";
import Backdrop from "./d-sheet/backdrop";
import BleedingBackground from "./d-sheet/bleeding-background";
import Content from "./d-sheet/content";
import Handle from "./d-sheet/handle";
import Header from "./d-sheet/header";
import Outlet from "./d-sheet/outlet";
import Portal from "./d-sheet/portal";
import Root from "./d-sheet/root";
import SpecialWrapperContent from "./d-sheet/special-wrapper/content";
import SpecialWrapperRoot from "./d-sheet/special-wrapper/root";
import Trigger from "./d-sheet/trigger";
import View from "./d-sheet/view";
import StackRoot from "./d-sheet-stack";

/**
 * Namespace object exposing all DSheet sub-components for building sheet UIs.
 *
 * @type {{
 *   Root: typeof Root,
 *   Backdrop: typeof Backdrop,
 *   BleedingBackground: typeof BleedingBackground,
 *   Handle: typeof Handle,
 *   Outlet: typeof Outlet,
 *   Portal: typeof Portal,
 *   View: typeof View,
 *   Content: typeof Content,
 *   Trigger: typeof Trigger,
 *   Header: typeof Header,
 *   SpecialWrapper: { Root: typeof SpecialWrapperRoot, Content: typeof SpecialWrapperContent },
 *   Scroll: { Root: typeof ScrollRoot, View: typeof ScrollView, Content: typeof ScrollContent },
 *   Stack: { Root: typeof StackRoot }
 * }}
 */
const DSheet = {
  /** @type {typeof Root} */
  Root,
  /** @type {typeof Backdrop} */
  Backdrop,
  /** @type {typeof BleedingBackground} */
  BleedingBackground,
  /** @type {typeof Handle} */
  Handle,
  /** @type {typeof Outlet} */
  Outlet,
  /** @type {typeof Portal} */
  Portal,
  /** @type {typeof View} */
  View,
  /** @type {typeof Content} */
  Content,
  /** @type {typeof Trigger} */
  Trigger,
  /** @type {typeof Header} */
  Header,
  /**
   * Sub-components for special wrapper layouts (e.g. Toast).
   *
   * @type {{ Root: typeof SpecialWrapperRoot, Content: typeof SpecialWrapperContent }}
   */
  SpecialWrapper: {
    /** @type {typeof SpecialWrapperRoot} */
    Root: SpecialWrapperRoot,
    /** @type {typeof SpecialWrapperContent} */
    Content: SpecialWrapperContent,
  },
  /**
   * Scroll sub-components for scrollable content within sheets.
   *
   * @type {{ Root: typeof ScrollRoot, View: typeof ScrollView, Content: typeof ScrollContent }}
   */
  Scroll: {
    /** @type {typeof ScrollRoot} */
    Root: ScrollRoot,
    /** @type {typeof ScrollView} */
    View: ScrollView,
    /** @type {typeof ScrollContent} */
    Content: ScrollContent,
  },
  /**
   * Stack sub-components for managing stacked sheets.
   *
   * @type {{ Root: typeof StackRoot }}
   */
  Stack: {
    /** @type {typeof StackRoot} */
    Root: StackRoot,
  },
};

export default DSheet;
