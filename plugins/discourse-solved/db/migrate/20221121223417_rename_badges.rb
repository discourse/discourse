# frozen_string_literal: true

class RenameBadges < ActiveRecord::Migration[6.1]
  HELPDESK_TRANSLATIONS = {
    "ar" => "مكتب المساعدة",
    "el" => "Γραφείο βοήθειας",
    "es" => "Servicio de ayuda",
    "fi" => "Neuvonta",
    "fr" => "Service d'assistance",
    "he" => "דלפק עזרה",
    "hu" => "Ügyfélszolgálat",
    "ja" => "ヘルプデスク",
    "ko" => "안내 데스크",
    "pl_PL" => "Dział pomocy technicznej",
    "ro" => "Ajutor",
    "ru" => "Служба поддержки",
    "sl" => "Služba za pomoč",
    "sv" => "Kundtjänst",
    "tr_TR" => "Yardım masası",
    "zh_CN" => "帮助台",
    "zh_TW" => "服務台",
  }

  TECH_SUPPORT_TRANSLATIONS = {
    "ar" => "الدعم الفني",
    "de" => "Technischer Support",
    "el" => "Τεχνική υποστήριξη",
    "es" => "Asistencia técnica",
    "fi" => "Tukipalvelu",
    "fr" => "Assistance technique",
    "he" => "תמיכה טכנית",
    "hu" => "Műszaki támogatás",
    "id" => "Dukungan Teknis",
    "it" => "Supporto Tecnico",
    "ja" => "技術サポート",
    "ko" => "기술 지원",
    "nl" => "Technische ondersteuning",
    "pl_PL" => "Wsparcie techniczne",
    "pt_BR" => "Suporte Técnico",
    "ro" => "Asistenţă tehnică",
    "ru" => "Техническая поддержка",
    "sl" => "Tehnična podpora",
    "sv" => "Teknisk support",
    "tr_TR" => "Teknik Destek",
    "zh_CN" => "技术支持",
    "zh_TW" => "技術支援",
  }

  def up
    default_locale =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'default_locale'").first || "en"

    sql = <<~SQL
      UPDATE badges
      SET name             = :new_name,
          description      = NULL,
          long_description = NULL
      WHERE name = :old_name
    SQL

    badge_name = HELPDESK_TRANSLATIONS.fetch(default_locale, "Helpdesk")
    DB.exec(sql, old_name: badge_name, new_name: "Solved 1")

    badge_name = TECH_SUPPORT_TRANSLATIONS.fetch(default_locale, "Tech Support")
    DB.exec(sql, old_name: badge_name, new_name: "Solved 2")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
