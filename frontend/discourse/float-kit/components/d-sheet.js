import ScrollContent from "./d-scroll/content";
import ScrollRoot from "./d-scroll/root";
import ScrollTrigger from "./d-scroll/trigger";
import ScrollView from "./d-scroll/view";
import Backdrop from "./d-sheet/backdrop";
import BleedingBackground from "./d-sheet/bleeding-background";
import Content from "./d-sheet/content";
import Description from "./d-sheet/description";
import Handle from "./d-sheet/handle";
import Header from "./d-sheet/header";
import Outlet from "./d-sheet/outlet";
import Portal from "./d-sheet/portal";
import Root from "./d-sheet/root";
import SpecialWrapperContent from "./d-sheet/special-wrapper/content";
import SpecialWrapperRoot from "./d-sheet/special-wrapper/root";
import Title from "./d-sheet/title";
import Trigger from "./d-sheet/trigger";
import View from "./d-sheet/view";
import StackRoot from "./d-sheet-stack";
import StackOutlet from "./d-sheet-stack-outlet";

const DSheet = {
  Root,
  Backdrop,
  BleedingBackground,
  Handle,
  Outlet,
  Portal,
  View,
  Content,
  Description,
  Trigger,
  Header,
  Title,
  SpecialWrapper: {
    Root: SpecialWrapperRoot,
    Content: SpecialWrapperContent,
  },
  Scroll: {
    Root: ScrollRoot,
    View: ScrollView,
    Content: ScrollContent,
    Trigger: ScrollTrigger,
  },
  Stack: {
    Root: StackRoot,
    Outlet: StackOutlet,
  },
};

export default DSheet;
