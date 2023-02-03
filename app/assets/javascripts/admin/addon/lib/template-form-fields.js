export const templateFormFields = [
  {
    type: "checkbox",
    structure: `- type: checkbox
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    label: "Enter question here"
    description: "Enter description here"
    validations:
      required: true`,
  },
  {
    type: "input",
    structure: `- type: input
  attributes:
    label: "Enter input label here"
    description: "Enter input description here"
    placeholder: "Enter input placeholder here"
    validations:
      required: true`,
  },
  {
    type: "textarea",
    structure: `- type: textarea
  attributes:
    label: "Enter textarea label here"
    description: "Enter textarea description here"
    placeholder: "Enter textarea placeholder here"
    validations:
      required: true`,
  },
  {
    type: "dropdown",
    structure: `- type: dropdown
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    label: "Enter dropdown label here"
    description: "Enter dropdown description here"
    validations:
      required: true`,
  },
  {
    type: "upload",
    structure: `- type: upload
  attributes:
    file_types: "jpg, png, gif"
    label: "Enter upload label here"
    description: "Enter upload description here"`,
  },
  {
    type: "multiselect",
    structure: `- type: multiple_choice
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    label: "Enter multiple choice label here"
    description: "Enter multiple choice description here"
    validations:
      required: true`,
  },
];
