// TODO(@keegan): Add translations for template strings
export const templateFormFields = [
  {
    type: "checkbox",
    structure: `- type: checkbox
  attributes:
    label: "Enter question here"
  validations:
    # enter validations here`,
  },
  {
    type: "input",
    structure: `- type: input
  attributes:
    label: "Enter input label here"
    placeholder: "Enter input placeholder here"
  validations:
    # enter validations here`,
  },
  {
    type: "textarea",
    structure: `- type: textarea
  attributes:
    label: "Enter textarea label here"
    placeholder: "Enter textarea placeholder here"
  validations:
    # enter validations here`,
  },
  {
    type: "dropdown",
    structure: `- type: dropdown
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    none_label: "Select an item"
    label: "Enter dropdown label here"
    filterable: false
  validations:
    # enter validations here`,
  },
  {
    type: "upload",
    structure: `- type: upload
  attributes:
    file_types: "jpg, png, gif"
    allow_multiple: false
    label: "Enter upload label here"
  validations:
    # enter validations here`,
  },
  {
    type: "multiselect",
    structure: `- type: multi-select
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    none_label: "Select an item"
    label: "Enter multiple choice label here"
  validations:
    # enter validations here`,
  },
];
