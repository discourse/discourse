# frozen_string_literal: true

class RenameBadge < ActiveRecord::Migration[6.1]
  TRANSLATIONS = {
    "ar" => "أول تفاعل",
    "de" => "Erste Reaktion",
    "es" => "Primera reacción",
    "fa_IR" => "اولین واکنش",
    "fi" => "Ensimmäinen reaktio",
    "fr" => "Première réaction",
    "he" => "תחושה ראשונה",
    "hu" => "Első reakció",
    "it" => "Prima reazione",
    "ja" => "最初のリアクション",
    "pl_PL" => "Pierwsza reakcja",
    "pt" => "Primeira Reação",
    "pt_BR" => "Primeira Reação",
    "ru" => "Первая реакция",
    "sv" => "Första reaktionen",
    "zh_CN" => "首次回应",
    "zh_TW" => "頭一個反應",
  }

  def up
    default_locale =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'default_locale'").first || "en"
    default_badge_name = "First Reaction"
    badge_name = TRANSLATIONS.fetch(default_locale, default_badge_name)

    if badge_name != default_badge_name
      default_badge_id =
        DB.query_single("SELECT id FROM badges WHERE name = :name", name: default_badge_name).first

      if default_badge_id
        DB.exec("DELETE FROM badges WHERE id = :id", id: default_badge_id)
        DB.exec("DELETE FROM user_badges WHERE badge_id = :id", id: default_badge_id)
      end
    end

    sql = <<~SQL
      UPDATE badges
      SET name             = :new_name,
          description      = NULL,
          long_description = NULL
      WHERE name = :old_name
    SQL

    DB.exec(sql, old_name: badge_name, new_name: default_badge_name)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
