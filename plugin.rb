# frozen_string_literal: true

# name: discourse-westan-ranking
# about: Weekly engagement ranking for Discourse communities
# meta_topic_id: 0
# version: 0.1.0
# authors: Westan
# url: https://github.com/forumwestan/discourse-westan-ranking
# required_version: 3.2.0

enabled_site_setting :westan_ranking_enabled

register_asset "stylesheets/westan-ranking/ranking.scss"

register_svg_icon "crown"
register_svg_icon "gear"
register_svg_icon "circle-info"
register_svg_icon "calendar-days"
register_svg_icon "wand-magic-sparkles"
register_svg_icon "xmark"
register_svg_icon "magnifying-glass"
register_svg_icon "trash-can"

module ::WestanRanking
  PLUGIN_NAME = "discourse-westan-ranking"
end

require_relative "lib/westan_ranking/engine"

after_initialize do
  require_relative "app/controllers/westan_ranking/ranking_controller"

  WestanRanking::Engine.routes.draw do
    get   "/"        => "ranking#index"
    patch "/config"  => "ranking#update_config"
    get   "/users"   => "ranking#search_users"
  end

  Discourse::Application.routes.prepend do
    get   "/westan/ranking"        => "westan_ranking/ranking#index"
    patch "/westan/ranking/config" => "westan_ranking/ranking#update_config"
    get   "/westan/ranking/users"  => "westan_ranking/ranking#search_users"
  end

  Discourse::Application.routes.append do
    get "/ranking" => "list#latest"
    get "/ranking/*path" => "list#latest"
  end
end
