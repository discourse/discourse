import StyleguideExample from "../../styleguide-example";
import I18n from "I18n";

const t = I18n.t.bind(I18n);

<template>
  <StyleguideExample @title="h1">
    <h1>{{t "styleguide.sections.typography.example"}}</h1>
  </StyleguideExample>

  <StyleguideExample @title="h2">
    <h2>{{t "styleguide.sections.typography.example"}}</h2>
  </StyleguideExample>

  <StyleguideExample @title="h3">
    <h3>{{t "styleguide.sections.typography.example"}}</h3>
  </StyleguideExample>

  <StyleguideExample @title="h4">
    <h4>{{t "styleguide.sections.typography.example"}}</h4>
  </StyleguideExample>

  <StyleguideExample @title="h5">
    <h5>{{t "styleguide.sections.typography.example"}}</h5>
  </StyleguideExample>

  <StyleguideExample @title="h6">
    <h6>{{t "styleguide.sections.typography.example"}}</h6>
  </StyleguideExample>

  <StyleguideExample @title="p">
    <p>{{t "styleguide.sections.typography.paragraph"}}</p>
  </StyleguideExample>
</template>
