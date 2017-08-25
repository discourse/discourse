# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :annotator_store_range, class: AnnotatorStore::Range do |f|
    f.start '/p[69]/span/span'
    f.end '/p[70]/span/span'
    f.start_offset 0
    f.end_offset 120

    f.association :annotation, factory: :annotator_store_annotation
  end
end
