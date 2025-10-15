import AiPersonaListEditor from "../../../../../discourse/components/ai-persona-list-editor";

<template>
  <AiPersonaListEditor
    @personas={{@controller.allPersonas}}
    @currentPersona={{@controller.model}}
  />
</template>
