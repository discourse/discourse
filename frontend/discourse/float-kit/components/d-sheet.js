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

const DSheet = {
  Root,
  Backdrop,
  BleedingBackground,
  Handle,
  Outlet,
  Portal,
  View,
  Content,
  Trigger,
  Header,
  SpecialWrapper: {
    Root: SpecialWrapperRoot,
    Content: SpecialWrapperContent,
  },
  Scroll: {
    Root: ScrollRoot,
    View: ScrollView,
    Content: ScrollContent,
  },
  Stack: {
    Root: StackRoot,
  },
};

export default DSheet;
