import MultiSelect from "discourse/select-kit/components/multi-select";

const OPTIONS = [
  { id: 1, name: "Orange" },
  { id: 2, name: "Blue" },
  { id: 3, name: "Red" },
  { id: 4, name: "Yellow" },
];

export default <template>
  <MultiSelect @content={{OPTIONS}} @onChange={{@onChange}} />
</template>
