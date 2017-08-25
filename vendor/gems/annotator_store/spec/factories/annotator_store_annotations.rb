# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :annotator_store_annotation, class: AnnotatorStore::Annotation do
    version "v#{Faker::App.version}"
    text Faker::Lorem.sentence
    quote Faker::Lorem.sentence
    uri Faker::Internet.url
  end
end
