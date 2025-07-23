# frozen_string_literal: true

Fabricator(:template_item, from: :topic) do
  transient :content

  title { sequence(:title) { |i| "This is a test template #{i.to_s.rjust(6, "0")}" } }

  after_create do |topic, transients|
    Fabricate(:post, topic: topic) do
      raw do
        if transients[:content]
          transients[:content]
        else
          sequence(:title) do |i|
            "This is the content of an awesome template #{i.to_s.rjust(6, "0")}"
          end
        end
      end
    end
  end
end

Fabricator(:private_template_item, from: :private_message_topic) do
  transient :content

  title { sequence(:title) { |i| "This is a private test template #{i.to_s.rjust(6, "0")}" } }

  after_create do |topic, transients|
    Fabricate(:post, topic: topic) do
      raw do
        if transients[:content]
          transients[:content]
        else
          sequence(:title) do |i|
            "This is the content of an awesome private template #{i.to_s.rjust(6, "0")}"
          end
        end
      end
    end
  end
end
