BadgeType.seed do |b|
  b.id = 1
  b.name = I18n.t('badges.types.gold')
  b.color_hexcode = "ffd700"
end

BadgeType.seed do |b|
  b.id = 2
  b.name = I18n.t('badges.types.silver')
  b.color_hexcode = "c0c0c0"
end

BadgeType.seed do |b|
  b.id = 3
  b.name = I18n.t('badges.types.bronze')
  b.color_hexcode = "cd7f32"
end
