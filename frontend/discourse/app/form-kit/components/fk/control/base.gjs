import Component from "@glimmer/component";

export default class FKBaseControl extends Component {
  constructor(owner, args) {
    super(owner, args);

    // Legacy path: when @type is not set on <form.Field />,
    // controls set field.type via their static controlType property.
    if (!args.field.hasExplicitType) {
      args.field.type = this.constructor.controlType;
    }
  }

  get field() {
    return this.args.field;
  }
}
