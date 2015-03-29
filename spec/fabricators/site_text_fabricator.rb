Fabricator(:site_text) do
  text_type "great.poem"
  value "%{flower} are red. %{food} are blue."
end

Fabricator(:site_text_basic, from: :site_text) do
  text_type "breaking.bad"
  value "best show ever"
end

Fabricator(:site_text_site_setting, from: :site_text) do
  text_type "site.replacement"
  value "%{title} is evil."
end
