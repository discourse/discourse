import FKControlCalendar from "discourse/form-kit/components/fk/control/calendar";
import FKControlCheckbox from "discourse/form-kit/components/fk/control/checkbox";
import FKControlCode from "discourse/form-kit/components/fk/control/code";
import FKControlColor from "discourse/form-kit/components/fk/control/color";
import FKControlComposer from "discourse/form-kit/components/fk/control/composer";
import FKControlCustom from "discourse/form-kit/components/fk/control/custom";
import FKControlEmoji from "discourse/form-kit/components/fk/control/emoji";
import FKControlIcon from "discourse/form-kit/components/fk/control/icon";
import FKControlImage from "discourse/form-kit/components/fk/control/image";
import FKControlInput from "discourse/form-kit/components/fk/control/input";
import FKControlMenu from "discourse/form-kit/components/fk/control/menu";
import FKControlPassword from "discourse/form-kit/components/fk/control/password";
import FKControlQuestion from "discourse/form-kit/components/fk/control/question";
import FKControlRadioGroup from "discourse/form-kit/components/fk/control/radio-group";
import FKControlSelect from "discourse/form-kit/components/fk/control/select";
import FKControlTagChooser from "discourse/form-kit/components/fk/control/tag-chooser";
import FKControlTextarea from "discourse/form-kit/components/fk/control/textarea";
import FKControlToggle from "discourse/form-kit/components/fk/control/toggle";

const CONTROL_COMPONENTS = {
  calendar: FKControlCalendar,
  checkbox: FKControlCheckbox,
  code: FKControlCode,
  color: FKControlColor,
  composer: FKControlComposer,
  custom: FKControlCustom,
  emoji: FKControlEmoji,
  icon: FKControlIcon,
  image: FKControlImage,
  input: FKControlInput,
  menu: FKControlMenu,
  password: FKControlPassword,
  question: FKControlQuestion,
  "radio-group": FKControlRadioGroup,
  select: FKControlSelect,
  "tag-chooser": FKControlTagChooser,
  textarea: FKControlTextarea,
  toggle: FKControlToggle,
};

export function resolveFieldControl(type) {
  if (!type) {
    throw new Error("@type is required on `<form.Field />`.");
  }

  if (type.startsWith("input-")) {
    return {
      component: FKControlInput,
      args: {
        type: type.slice("input-".length),
      },
    };
  }

  const component = CONTROL_COMPONENTS[type];

  if (!component) {
    throw new Error(`Unsupported \`<form.Field @type>\` value: "${type}".`);
  }

  return { component, args: {} };
}
