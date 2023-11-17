import unused from "discourse-plugin/helpers/unused";

<template>
  This file is intentionally unused. It is to demonstrate unused files are never
  built, let alone included into the bundle. If this file is ever processed by
  the build, the import above will cause a build-time error.
  {{unused}}
</template>
