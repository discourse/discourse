import Component from "@glimmer/component";
import Col from "form-kit/components/col";
import Label from "form-kit/components/label";
import Row from "form-kit/components/row";

export default class FieldWrapper extends Component {
  isGroup = false;

  isHorizontal = this.args.node.props.horizontal;

  <template>
    {{#if this.isGroup}}
      {{! TODO: IMPLEMENT MULTI INPUTS }}
    {{else}}
      {{#if this.isHorizontal}}
        <Row>
          <Col @size={{4}}>
            <Label
              @label={{@label}}
              @name={{@node.config.name}}
              @optional={{@node.props.optional}}
            />
          </Col>
          <Col @size={{8}}>
            <div class="d-form-field__value">
              <@component
                @node={{@node}}
                @validation={{@validation}}
                @name={{@name}}
                @help={{@help}}
                @value={{@value}}
                @info={{@info}}
              />
            </div>
          </Col>
        </Row>
      {{else}}
        <Row>
          <Col @size={{@size}}>
            <div class="d-form-field__value">
              <@component
                @node={{@node}}
                @label={{@label}}
                @validation={{@validation}}
                @name={{@name}}
                @help={{@help}}
                @value={{@value}}
                @info={{@info}}
              />
            </div>
          </Col>
        </Row>
      {{/if}}
    {{/if}}
  </template>
}
